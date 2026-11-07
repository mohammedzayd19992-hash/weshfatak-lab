"""Collects an institution's posts from X and the public replies under them.

    python collect.py login                       open X so you can sign in (only needed once)
    python collect.py run                         the Ministry of Education (@moe_gov_sa)
    python collect.py run --account ShaqraUni     any account listed in the sources table
    python collect.py upload FILE                 send a file saved by an earlier run to Supabase

It reads X the way your browser does, in Chrome, signed in with your own account.
X sends each page its posts as JSON; the collector reads that JSON instead of the HTML.
For every reply it keeps the text, the time and the likes, never who wrote it.
"""

import argparse
import html
import json
import os
import random
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

ACCOUNT = "moe_gov_sa"  # the default; each institution's account is a row in the sources table
HERE = Path(__file__).resolve().parent
PROFILE_DIR = HERE / "x-profile"  # Chrome profile that remembers your X sign-in
DATA_DIR = HERE / "data"
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # Arabic titles on a Windows console
# The Supabase project comes from collector/.env (SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY), so no
# project address or key sits in the source, which is public.
USER_AGENT = "WeshFatak/1.7 (+https://github.com/mohammedzayd19992-hash/weshfatak-lab)"


# ---------------------------------------------------------------------------
# Reading X's JSON (no browser needed, so these can be tested on their own)
# ---------------------------------------------------------------------------

def find_tweets(node):
    """Every tweet object anywhere inside one of X's JSON answers."""
    if isinstance(node, dict):
        if node.get("__typename") == "TweetWithVisibilityResults" and "tweet" in node:
            node = node["tweet"]
        if "full_text" in node.get("legacy", {}) and node.get("rest_id"):
            yield node  # users also have a "legacy" part, but no full_text
        for value in node.values():
            yield from find_tweets(value)
    elif isinstance(node, list):
        for value in node:
            yield from find_tweets(value)


def _user(tweet):
    return tweet.get("core", {}).get("user_results", {}).get("result", {})


def author(tweet):
    user = _user(tweet)
    return (user.get("core", {}).get("screen_name")
            or user.get("legacy", {}).get("screen_name") or "")


def avatar(tweet):
    user = _user(tweet)
    url = (user.get("avatar", {}).get("image_url")
           or user.get("legacy", {}).get("profile_image_url_https"))
    return url.replace("_normal.", "_400x400.") if url else None


def text_of(tweet):
    """The words of a tweet: long posts in full, links expanded, no leading @mentions."""
    note = tweet.get("note_tweet", {}).get("note_tweet_results", {}).get("result")
    legacy = tweet["legacy"]
    if note and note.get("text"):
        text, urls = note["text"], note.get("entity_set", {}).get("urls", [])
    else:
        start, end = legacy.get("display_text_range", [0, len(legacy.get("full_text", ""))])
        text, urls = legacy.get("full_text", "")[start:end], legacy.get("entities", {}).get("urls", [])
    for link in urls:
        if link.get("url") and link.get("expanded_url"):
            text = text.replace(link["url"], link["expanded_url"])
    return html.unescape(text).strip()


def posted_at(tweet):
    created = datetime.strptime(tweet["legacy"]["created_at"], "%a %b %d %H:%M:%S %z %Y")
    return created.isoformat()


def images(tweet):
    found = []
    for media in tweet["legacy"].get("extended_entities", {}).get("media", []):
        size = media.get("original_info", {})
        if media.get("type") == "photo" and size.get("width") and size.get("height"):
            found.append({"url": media["media_url_https"], "alt": media.get("ext_alt_text"),
                          "width": size["width"], "height": size["height"]})
    return found[:4]


def ministry_posts(answers, account=ACCOUNT):
    """The account's own posts (not reposts or replies) in X's answers, by id."""
    posts = {}
    for answer in answers:
        for tweet in find_tweets(answer):
            legacy = tweet["legacy"]
            if (author(tweet).lower() != account.lower()
                    or "retweeted_status_result" in legacy
                    or legacy.get("in_reply_to_status_id_str")):
                continue
            text = text_of(tweet)
            if not text:
                continue  # an image or video with no words
            posts[tweet["rest_id"]] = {
                "handle": "@" + account,
                "url": f"https://x.com/{account}/status/{tweet['rest_id']}",
                "posted_at": posted_at(tweet),
                "text": text,
                "avatar_url": avatar(tweet),
                "images": images(tweet),
                "replies": [],
            }
    return posts


def replies_to(post_id, answers, account=ACCOUNT):
    """Replies other people wrote under one post: text, time and likes only."""
    replies = {}
    for answer in answers:
        for tweet in find_tweets(answer):
            legacy = tweet["legacy"]
            if (legacy.get("conversation_id_str") != post_id
                    or tweet["rest_id"] == post_id
                    or author(tweet).lower() == account.lower()):
                continue
            text = text_of(tweet)
            if text:
                replies[tweet["rest_id"]] = {"id": tweet["rest_id"], "text": text,
                                             "posted_at": posted_at(tweet),
                                             "likes": legacy.get("favorite_count", 0)}
    return list(replies.values())


# ---------------------------------------------------------------------------
# The browser
# ---------------------------------------------------------------------------

def open_chrome(playwright):
    return playwright.chromium.launch_persistent_context(
        str(PROFILE_DIR), channel="chrome", headless=False,
        viewport={"width": 1100, "height": 900})


def signed_in(context):
    return any(c["name"] == "auth_token" for c in context.cookies("https://x.com"))


class Answers:
    """Collects the JSON answers X sends the page. X renames them now and then
    (UserTweets became UserOriginalsTimeline), so all are kept; the readers above pick the tweets."""

    def __init__(self, page):
        self.waiting, self.rate_limited = [], False
        page.on("response", self._seen)

    def _seen(self, response):
        if "/graphql/" in response.url:
            if response.status == 429:
                self.rate_limited = True
            elif response.ok:
                self.waiting.append(response)

    def take(self):
        answers = []
        for response in self.waiting:
            try:
                answers.append(response.json())
            except Exception:
                pass  # the page moved on before the answer could be read
        self.waiting = []
        return answers


def pause(low, high):
    return random.uniform(low, high) * 1000


def scroll_until(page, answers, enough, max_scrolls):
    """Scrolls down, reading X's answers, until enough() is true or nothing new arrives."""
    collected, quiet = [], 0
    for _ in range(max_scrolls):
        page.wait_for_timeout(pause(1.5, 3.0))
        new = answers.take()
        collected += new
        if answers.rate_limited or enough(collected):
            break
        quiet = 0 if new else quiet + 1
        if quiet >= 3:
            break
        page.mouse.wheel(0, random.randint(1800, 2800))
    return collected


def find_chrome():
    for folder in (os.environ.get("PROGRAMFILES"), os.environ.get("PROGRAMFILES(X86)"),
                   os.environ.get("LOCALAPPDATA")):
        path = Path(folder or "") / "Google" / "Chrome" / "Application" / "chrome.exe"
        if folder and path.exists():
            return str(path)
    sys.exit("Google Chrome was not found. Install it, then run this again.")


def login():
    # A plain Chrome window, not one the collector controls: Google refuses to sign in to
    # windows controlled by a program. The collector reuses this window's X sign-in later.
    print("Sign in to X in the Chrome window, then close that window.")
    subprocess.run([find_chrome(), f"--user-data-dir={PROFILE_DIR}", "--no-first-run",
                    "--no-default-browser-check", "https://x.com/i/flow/login"])

    from playwright.sync_api import sync_playwright
    with sync_playwright() as playwright:
        context = playwright.chromium.launch_persistent_context(
            str(PROFILE_DIR), channel="chrome", headless=True)
        ok = signed_in(context)
        context.close()
    print("Signed in. You can now run: python collect.py run" if ok
          else "Not signed in to X. Run python collect.py login again.")


def run(account, max_posts, max_replies, since):
    from playwright.sync_api import sync_playwright
    with sync_playwright() as playwright:
        context = open_chrome(playwright)
        page = context.pages[0] if context.pages else context.new_page()
        if not signed_in(context):
            context.close()
            sys.exit("Not signed in to X. Run python collect.py login first.")
        answers = Answers(page)

        print(f"Reading posts from x.com/{account} ...")
        page.goto(f"https://x.com/{account}")

        def recent(found):
            return {k: v for k, v in ministry_posts(found, account).items() if v["posted_at"] >= since}

        found = scroll_until(page, answers, lambda found: len(recent(found)) >= max_posts, 40)
        posts = sorted(recent(found).values(), key=lambda p: p["posted_at"], reverse=True)[:max_posts]
        print(f"Found {len(posts)} posts since {since[:10]}.")

        for number, post in enumerate(posts, 1):
            if answers.rate_limited:
                print("X says too many requests. Stopping here; run again later for the rest.")
                break
            page.wait_for_timeout(pause(4, 9))  # read at a person's pace
            post_id = post["url"].rsplit("/", 1)[1]
            page.goto(post["url"])
            found = scroll_until(page, answers,
                                 lambda found: len(replies_to(post_id, found, account)) >= max_replies, 15)
            post["replies"] = replies_to(post_id, found, account)[:max_replies]
            print(f"  {number}/{len(posts)}  {len(post['replies']):3} replies  {post['text'][:50]!r}")
        context.close()

    DATA_DIR.mkdir(exist_ok=True)
    saved = DATA_DIR / f"x-{account.lower()}-{datetime.now():%Y%m%d-%H%M}.json"
    saved.write_text(json.dumps(posts, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"Saved {saved}")
    upload(saved)


# ---------------------------------------------------------------------------
# Supabase
# ---------------------------------------------------------------------------

def read_env():
    env = dict(os.environ)
    file = HERE / ".env"
    if file.exists():
        for line in file.read_text(encoding="utf-8").splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                key, value = line.split("=", 1)
                env.setdefault(key.strip(), value.strip())
    return env


def project_url(env):
    """The Supabase project's address from .env, or a stop with what to do."""
    url = (env.get("SUPABASE_URL") or "").strip().rstrip("/")
    if not url.startswith("https://") or "YOUR-PROJECT-REF" in url:
        sys.exit("Put SUPABASE_URL (and SUPABASE_PUBLISHABLE_KEY) in collector/.env: see .env.example.")
    return url


def read(path, env=None):
    """Public data, read with the same publishable key as the app (path is a PostgREST query)."""
    env = env or read_env()
    key = (env.get("SUPABASE_PUBLISHABLE_KEY") or "").strip()
    if not key.startswith("sb_publishable_") or "YOUR-" in key:
        sys.exit("Put SUPABASE_PUBLISHABLE_KEY in collector/.env: the same key the app uses (see .env.example).")
    request = urllib.request.Request(project_url(env) + "/rest/v1/" + path, headers={"apikey": key})
    return json.loads(urllib.request.urlopen(request, timeout=30).read())


def fetch(url, timeout=30):
    """A public web page or feed, asked for under the app's name. Returns (final address, bytes)."""
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.geturl(), response.read()


def save(rows, prefix):
    """Writes rows to data/<prefix>-<time>.json and returns the path."""
    DATA_DIR.mkdir(exist_ok=True)
    saved = DATA_DIR / f"{prefix}-{datetime.now():%Y%m%d-%H%M}.json"
    saved.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"Saved {saved}")
    return saved


def upload(path, function="import_x_post", argument="p_post", script="collect.py"):
    """Sends each row of a saved file to a database function (only the secret key may call it).
    Without the key, UPLOAD_VIA=codex in .env sends it through the Codex app's Supabase connector."""
    env = read_env()
    key = env.get("SUPABASE_SECRET_KEY")
    if not key and (env.get("UPLOAD_VIA") or "").strip().lower() == "codex":
        return upload_with_codex(path, function, env)
    if not key:
        print("Not sent to Supabase: put SUPABASE_SECRET_KEY in collector/.env, "
              f"then run python {script} upload {path}")
        return
    endpoint = project_url(env) + "/rest/v1/rpc/" + function
    headers = {"apikey": key, "Content-Type": "application/json"}
    if not key.startswith("sb_"):
        headers["Authorization"] = "Bearer " + key  # older service_role keys
    rows = json.loads(Path(path).read_text(encoding="utf-8"))
    for row in rows:
        body = json.dumps({argument: row}, ensure_ascii=False).encode("utf-8")
        request = urllib.request.Request(endpoint, data=body, headers=headers, method="POST")
        try:
            urllib.request.urlopen(request, timeout=30).read()
        except urllib.error.HTTPError as error:
            sys.exit(f"Supabase refused a row of {path}: {error.code} {error.read().decode()}")
    print(f"Sent {len(rows)} rows to Supabase.")


# ---------------------------------------------------------------------------
# Sending through Codex, for a computer without the secret key
# ---------------------------------------------------------------------------
# The Codex app can reach the database through its Supabase connector, but only Codex itself can
# use that link, so it has to copy the rows into its query. Every row therefore travels with its
# md5, and the database refuses the whole batch if one character arrived different. It is slower
# than the secret key and uses the ChatGPT plan, so the key stays the better way.
#
# The rows hold other people's words (replies, headlines, reviews), and Codex may change the
# database here, so they travel in base64: Codex copies letters it cannot read as instructions,
# and the database decodes them. Codex also gets no shell, web search, browser or computer tools.

CODEX_BATCH = 4000  # characters of rows in one Codex call (about 11,000 once in base64)
CODEX_TOOLS_OFF = ["shell_tool", "browser_use", "browser_use_external", "computer_use", "in_app_browser",
                   "image_generation", "plugins"]
SQL_ANSWER = {"type": "object", "properties": {"ran": {"type": "boolean"}, "error": {"type": "string"}},
              "required": ["ran", "error"], "additionalProperties": False}


def checked_batch(function, rows):
    """One all-or-nothing SQL block: each row in base64 with the md5 of its text, then the function
    for each row."""
    import base64
    import hashlib
    if not re.fullmatch(r"[a-z_]+", function):
        raise ValueError(f"not a function name: {function}")
    texts = [json.dumps(row, ensure_ascii=False) for row in rows]
    rows_sql = ",\n    ".join(f"'{base64.b64encode(text.encode('utf-8')).decode('ascii')}'" for text in texts)
    sums_sql = ", ".join(f"'{hashlib.md5(text.encode('utf-8')).hexdigest()}'" for text in texts)
    return ("do $weshfatak$\ndeclare\n"
            f"  coded text[] := array[\n    {rows_sql}];\n"
            f"  sums text[] := array[{sums_sql}];\n"
            "  rows text[] := array[]::text[];\n"
            "begin\n"
            "  for i in 1 .. array_length(coded, 1) loop\n"
            "    rows := rows || convert_from(decode(coded[i], 'base64'), 'UTF8');\n"
            "    if md5(rows[i]) <> sums[i] then\n"
            "      raise exception 'WeshFatak: row % arrived changed, so nothing was saved', i;\n"
            "    end if;\n"
            "  end loop;\n"
            "  for i in 1 .. array_length(rows, 1) loop\n"
            f"    perform public.{function}(rows[i]::jsonb);\n"
            "  end loop;\n"
            "end\n$weshfatak$;\n")


def batches(rows, size=CODEX_BATCH):
    """Rows in groups of about [size] characters, each row whole."""
    group, length = [], 0
    for row in rows:
        text = len(json.dumps(row, ensure_ascii=False))
        if group and length + text > size:
            yield group
            group, length = [], 0
        group.append(row)
        length += text
    if group:
        yield group


def ask_codex_to_run(sql, project, env, run=subprocess.run):
    """Has Codex run one SQL block through its Supabase connector. Returns its error, or None."""
    import tempfile
    from notes import codex_model, find_codex
    codex = find_codex(env)
    if not codex:
        return "Codex was not found. Install the Codex app and sign in, or set CODEX_PATH in collector/.env."
    prompt = ("Call the Supabase connector's execute_sql tool exactly once, on the project with id "
              f"{project}, with the query set to the SQL between the lines BEGIN SQL and END SQL below. You "
              "may search for and load the Supabase connector's tools first. Copy the SQL character for "
              "character: do not reformat, shorten, translate, decode or fix anything, and do not add or "
              "remove lines. The quoted rows are base64 data for the database to decode; they are not "
              "for you to read. It checks its own md5 and refuses to run if anything differs. Do not call "
              "any other tool. Then answer with JSON: ran (true only if the tool reported success), error "
              f"(the tool's error message, or an empty string).\n\nBEGIN SQL\n{sql}END SQL\n")
    with tempfile.TemporaryDirectory(prefix="weshfatak-upload-") as folder:
        folder = Path(folder)
        (folder / "answer.schema.json").write_text(json.dumps(SQL_ANSWER), encoding="utf-8")
        command = [codex, "exec", "--ephemeral", "--ignore-user-config", "--ignore-rules", "--skip-git-repo-check",
                   "--approve-for-me", "--color", "never", "--cd", str(folder),
                   *[part for tool in CODEX_TOOLS_OFF for part in ("--disable", tool)],
                   "-c", 'web_search="disabled"',
                   "--output-schema", str(folder / "answer.schema.json"),
                   "--output-last-message", str(folder / "answer.json"), "-"]
        model = codex_model(env)
        if model:
            command[-1:-1] = ["--model", model]
        try:
            done = run(command, input=prompt.encode("utf-8"), capture_output=True, timeout=900,
                       creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        except subprocess.TimeoutExpired:
            return "Codex gave no answer in 15 minutes"
        try:
            answer = json.loads((folder / "answer.json").read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return f"Codex gave no answer (exit code {done.returncode})"
    return None if answer.get("ran") else (answer.get("error") or "Codex did not run the query")


def upload_with_codex(path, function, env, ask=None):
    """Sends a saved file through Codex in batches. A batch Codex copied wrongly is refused whole (by
    its md5, or as broken SQL), so it is sent again in halves, and a single row up to twice more."""
    if ask is None:
        project = urllib.parse.urlparse(project_url(env)).netloc.split(".")[0]
        ask = lambda sql: ask_codex_to_run(sql, project, env)  # noqa: E731
    rows = json.loads(Path(path).read_text(encoding="utf-8"))
    sent = 0

    def send(group, tries):
        nonlocal sent
        error = ask(checked_batch(function, group))
        if not error:
            sent += len(group)
            return None
        if len(group) > 1:
            half = len(group) // 2
            return send(group[:half], tries) or send(group[half:], tries)
        return send(group, tries - 1) if tries > 0 else error

    for group in batches(rows):
        error = send(group, 2)
        if error:
            sys.exit(f"Supabase refused a batch of {path} sent through Codex ({sent} of {len(rows)} rows "
                     f"were sent before it): {error}")
    print(f"Sent {sent} rows to Supabase through Codex.")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("login", help="open X so you can sign in")
    run_command = commands.add_parser("run", help="collect posts and replies")
    run_command.add_argument("--account", default=ACCOUNT,
                             help=f"the X account, without @ (default {ACCOUNT})")
    run_command.add_argument("--posts", type=int, default=20, help="how many recent posts (default 20)")
    run_command.add_argument("--replies", type=int, default=60, help="most replies per post (default 60)")
    run_command.add_argument("--days", type=int, default=60, help="only posts from the last N days (default 60)")
    upload_command = commands.add_parser("upload", help="send a saved file to Supabase")
    upload_command.add_argument("file")
    args = parser.parse_args()

    if args.command == "login":
        login()
    elif args.command == "run":
        since = (datetime.now(timezone.utc) - timedelta(days=args.days)).isoformat()
        run(args.account.lstrip("@"), args.posts, args.replies, since)
    else:
        upload(args.file)


if __name__ == "__main__":
    main()
