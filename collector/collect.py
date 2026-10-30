"""Collects Ministry of Education posts from X and the public replies under them.

    python collect.py login           open X so you can sign in (only needed once)
    python collect.py run             collect posts and replies, save them, send them to Supabase
    python collect.py upload FILE     send a file saved by an earlier run to Supabase

It reads X the way your browser does, in Chrome, signed in with your own account.
X sends each page its posts as JSON; the collector reads that JSON instead of the HTML.
For every reply it keeps the text, the time and the likes, never who wrote it.
"""

import argparse
import html
import json
import os
import random
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

ACCOUNT = "moe_gov_sa"
HANDLE = "@" + ACCOUNT
HERE = Path(__file__).resolve().parent
PROFILE_DIR = HERE / "x-profile"  # Chrome profile that remembers your X sign-in
DATA_DIR = HERE / "data"
DEFAULT_SUPABASE_URL = ""


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


def ministry_posts(answers):
    """The ministry's own posts (not reposts or replies) in X's answers, by id."""
    posts = {}
    for answer in answers:
        for tweet in find_tweets(answer):
            legacy = tweet["legacy"]
            if (author(tweet).lower() != ACCOUNT.lower()
                    or "retweeted_status_result" in legacy
                    or legacy.get("in_reply_to_status_id_str")):
                continue
            text = text_of(tweet)
            if not text:
                continue  # an image or video with no words
            posts[tweet["rest_id"]] = {
                "handle": HANDLE,
                "url": f"https://x.com/{ACCOUNT}/status/{tweet['rest_id']}",
                "posted_at": posted_at(tweet),
                "text": text,
                "avatar_url": avatar(tweet),
                "images": images(tweet),
                "replies": [],
            }
    return posts


def replies_to(post_id, answers):
    """Replies other people wrote under one post: text, time and likes only."""
    replies = {}
    for answer in answers:
        for tweet in find_tweets(answer):
            legacy = tweet["legacy"]
            if (legacy.get("conversation_id_str") != post_id
                    or tweet["rest_id"] == post_id
                    or author(tweet).lower() == ACCOUNT.lower()):
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


def run(max_posts, max_replies, since):
    from playwright.sync_api import sync_playwright
    with sync_playwright() as playwright:
        context = open_chrome(playwright)
        page = context.pages[0] if context.pages else context.new_page()
        if not signed_in(context):
            context.close()
            sys.exit("Not signed in to X. Run python collect.py login first.")
        answers = Answers(page)

        print(f"Reading posts from x.com/{ACCOUNT} ...")
        page.goto(f"https://x.com/{ACCOUNT}")

        def recent(found):
            return {k: v for k, v in ministry_posts(found).items() if v["posted_at"] >= since}

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
                                 lambda found: len(replies_to(post_id, found)) >= max_replies, 15)
            post["replies"] = replies_to(post_id, found)[:max_replies]
            print(f"  {number}/{len(posts)}  {len(post['replies']):3} replies  {post['text'][:50]!r}")
        context.close()

    DATA_DIR.mkdir(exist_ok=True)
    saved = DATA_DIR / f"moe-{datetime.now():%Y%m%d-%H%M}.json"
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


def upload(path, function="import_x_post", argument="p_post", script="collect.py"):
    """Sends each row of a saved file to a database function (only the secret key may call it)."""
    env = read_env()
    key = env.get("SUPABASE_SECRET_KEY")
    if not key:
        print("Not sent to Supabase: put SUPABASE_SECRET_KEY in collector/.env, "
              f"then run python {script} upload {path}")
        return
    endpoint = env.get("SUPABASE_URL", DEFAULT_SUPABASE_URL) + "/rest/v1/rpc/" + function
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


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("login", help="open X so you can sign in")
    run_command = commands.add_parser("run", help="collect posts and replies")
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
        run(args.posts, args.replies, since)
    else:
        upload(args.file)


if __name__ == "__main__":
    main()
