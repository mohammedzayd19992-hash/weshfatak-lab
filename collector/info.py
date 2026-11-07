"""Writes each institution's Info page, with what people ask about most first.

    python info.py                 work out every section, save it, send it to Supabase
    python info.py --no-status     the same without the study status (when press.py failed this round)
    python info.py upload FILE     send a file saved by an earlier run to Supabase

The sections, ordered by how many replies under the institution's posts asked about each in the
last ASKED_DAYS days (topics.py):
- status: is study suspended, online or back in person? The newest official posts and press
  reports about it from the last STATUS_DAYS days, newest first.
- dates: the coming dates of its academic calendar, from info/*.json, each with its source.
- help: where to ask: its official channels that answer, from info/*.json.
- apps and numbers: reviews.py and stats.py fill them; only their place is set here. The numbers
  always come last: nobody asked about them.
No AI: every item is an official post, a press headline or a line of an official calendar or
contact page, with its link.
"""

import argparse
import json
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import collect
import topics
from stories import normalize

HERE = Path(__file__).resolve().parent
ASKED_DAYS = 30   # replies from this long ago decide the order
STATUS_DAYS = 7   # study decisions older than this are no longer shown
MOST_STATUS = 4   # announcements shown at most
TITLE_LENGTH = 220


# ---------------------------------------------------------------------------
# Working out the sections (no network, so these can be tested on their own)
# ---------------------------------------------------------------------------

def headline(body):
    """A post's first line, cut at a word to TITLE_LENGTH characters."""
    line = next((line.strip() for line in (body or "").splitlines() if line.strip()), "")
    if len(line) <= TITLE_LENGTH:
        return line
    return line[:TITLE_LENGTH].rsplit(" ", 1)[0] + "…"


def status_items(cards, now):
    """The newest posts about study from the last STATUS_DAYS days, one per announcement."""
    since = now - timedelta(days=STATUS_DAYS)
    found, seen = [], set()
    for card in sorted(cards, key=lambda card: card["published_at"], reverse=True):
        posted = datetime.fromisoformat(card["published_at"])
        if posted < since or not topics.about_study(card["body"]):
            continue
        key = normalize(headline(card["body"]))[:60]
        if key in seen:
            continue  # the same headline from a second outlet
        seen.add(key)
        link = card["source_url"].split("#")[0]
        found.append({"title": headline(card["body"]), "published_at": card["published_at"],
                      "link": link, "source_name": card["source_name"], "source_url": link})
        if len(found) == MOST_STATUS:
            break
    return found


def upcoming(items, today):
    """Calendar dates that have not ended yet, soonest first."""
    def ends(item):
        return date.fromisoformat(item.get("ends_on") or item["starts_on"])
    return sorted((item for item in items if ends(item) >= today), key=lambda item: item["starts_on"])


def sections(organization, counts, status, written, today, with_status=True):
    """What save_info_section stores for one institution, most asked first. written is the
    institution's info/*.json (or {}); status its study posts, already chosen."""
    found = []
    for position, kind in enumerate(topics.order(counts), 1):
        if kind == "status" and not with_status:
            continue
        section = {"organization": organization, "kind": kind, "position": position,
                   "asked": counts.get(kind, 0)}
        if kind == "status":
            section["items"] = status
        elif kind in ("dates", "help"):
            part = written.get(kind) or {}
            section["note"] = part.get("note")
            items = part.get("items", [])
            section["items"] = upcoming(items, today) if kind == "dates" else items
        found.append(section)
    return found


def by_hand():
    """{institution name: its info/*.json}: calendars and contact channels, each with its source."""
    found = {}
    for file in sorted((HERE / "info").glob("*.json")):
        written = json.loads(file.read_text(encoding="utf-8"))
        found[written["organization"]] = written
    return found


# ---------------------------------------------------------------------------
# Supabase and the run
# ---------------------------------------------------------------------------

def stamp(time):
    """A time PostgREST reads in a query: 2026-11-04T09:00:00Z (a '+' would be read as a space)."""
    return time.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def read_all(path, env):
    rows, offset = [], 0
    while True:
        page = collect.read(f"{path}&limit=1000&offset={offset}", env)
        rows += page
        if len(page) < 1000:
            return rows
        offset += 1000


def replies_of(org, since, env):
    """The text of every reply under the institution's posts since a time."""
    ids = [row["news_id"] for row in
           read_all(f"news_cards?organization_id=eq.{org}&reply_count=gt.0&select=news_id&order=news_id", env)]
    bodies = []
    for start in range(0, len(ids), 100):
        chunk = ",".join(str(news_id) for news_id in ids[start:start + 100])
        bodies += [row["body"] for row in read_all(
            f"public_replies?news_id=in.({chunk})&posted_at=gte.{stamp(since)}&select=body&order=reply_id", env)]
    return bodies


def run(with_status):
    env = collect.read_env()
    now = datetime.now(timezone.utc)
    written = by_hand()
    found = []
    for org in collect.read("organizations?select=organization_id,name&order=position", env):
        counts = topics.asked_counts(replies_of(org["organization_id"], now - timedelta(days=ASKED_DAYS), env))
        cards = read_all(f"news_cards?organization_id=eq.{org['organization_id']}"
                         f"&published_at=gte.{stamp(now - timedelta(days=STATUS_DAYS))}"
                         "&select=body,published_at,source_url,source_name&order=published_at.desc", env)
        status = status_items(cards, now)
        made = sections(org["name"], counts, status, written.get(org["name"], {}),
                        now.astimezone().date(), with_status)
        found += made
        print(f"{org['name']}: " + ", ".join(f"{s['kind']} ({s['asked']} asked)" for s in made))
        if with_status:
            print(f"  study: {len(status)} announcement(s) in {STATUS_DAYS} days"
                  + "".join(f"\n    {item['published_at'][:16]}  {item['source_name']}  {item['title'][:70]}"
                            for item in status))
    send(collect.save(found, "info"))


def send(path):
    collect.upload(path, function="save_info_section", argument="p_section", script="info.py")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--no-status", action="store_true", help="leave the study status as it is")
    commands = parser.add_subparsers(dest="command")
    upload_command = commands.add_parser("upload", help="send a saved file to Supabase")
    upload_command.add_argument("file")
    args = parser.parse_args()
    if args.command == "upload":
        send(args.file)
    else:
        run(not args.no_status)


if __name__ == "__main__":
    sys.exit(main())
