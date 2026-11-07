"""Collects the written reviews of each institution's official apps from the App Store.

    python reviews.py                 every source with platform 'app_store', newest reviews first
    python reviews.py --pages 2       fewer pages per app (50 reviews a page, at most 10 pages)
    python reviews.py upload FILE     send a file saved by an earlier run to Supabase

Apple publishes each app's latest reviews as a public feed (itunes.apple.com/<country>/rss/
customerreviews). For each review it keeps the title, text, stars, app version and time, never who
wrote it. Each review starts with a face from its stars (5 or 4 happy, 3 neutral, 2 sad, 1 angry);
notes.py then has Claude read the words, since stars and words often disagree.
"""

import argparse
import json
import sys
import time
import urllib.error

import collect

COUNTRY = "sa"
FEED = "https://itunes.apple.com/{country}/rss/customerreviews/page={page}/id={app}/sortby=mostrecent/json"
FACES = {5: "happy", 4: "happy", 3: "neutral", 2: "sad", 1: "angry"}


# ---------------------------------------------------------------------------
# Reading Apple's feed (no network, so these can be tested on their own)
# ---------------------------------------------------------------------------

def label(entry, key):
    return ((entry.get(key) or {}).get("label") or "").strip()


def reviews_in(feed, source_url):
    """The reviews on one page of the feed, ready for import_review."""
    entries = feed.get("feed", {}).get("entry", [])
    if isinstance(entries, dict):
        entries = [entries]  # a page with one entry
    found = []
    for entry in entries:
        rating = label(entry, "im:rating")
        text = label(entry, "content")
        if not rating.isdigit() or not text:
            continue  # the app's own entry, or a rating with no words
        stars = int(rating)
        found.append({
            "source": source_url,
            "id": label(entry, "id"),
            "title": label(entry, "title"),
            "text": text,
            "rating": stars,
            "version": label(entry, "im:version") or None,
            "posted_at": label(entry, "updated"),
            "emotion": FACES.get(stars),
            "emotion_by": "stars",  # until notes.py reads the words
        })
    return found


# ---------------------------------------------------------------------------
# The run
# ---------------------------------------------------------------------------

def run(pages):
    env = collect.read_env()
    apps = collect.read("sources?platform=eq.app_store&select=name,url,handle", env)
    rows = []
    for app in apps:
        got = []
        for page in range(1, pages + 1):
            url = FEED.format(country=COUNTRY, page=page, app=app["handle"])
            try:
                _, raw = collect.fetch(url)
            except urllib.error.HTTPError as error:
                print(f"  {app['name']}: page {page} refused ({error.code}), stopping this app")
                break
            found = reviews_in(json.loads(raw), app["url"])
            if not found:
                break
            got += found
            time.sleep(1)
        unique = list({review["id"]: review for review in got}.values())
        print(f"{app['name']}: {len(unique)} reviews")
        rows += unique
    if rows:
        send(collect.save(rows, "reviews"))


def send(path):
    collect.upload(path, function="import_review", argument="p_review", script="reviews.py")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--pages", type=int, default=10, help="pages per app, 50 reviews each (default 10)")
    commands = parser.add_subparsers(dest="command")
    upload_command = commands.add_parser("upload", help="send a saved file to Supabase")
    upload_command.add_argument("file")
    args = parser.parse_args()
    if args.command == "upload":
        send(args.file)
    else:
        run(max(1, min(args.pages, 10)))


if __name__ == "__main__":
    sys.exit(main())
