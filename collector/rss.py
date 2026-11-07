"""Collects institution news from RSS feeds: every source with platform 'rss' and status 'collected'.

    python rss.py                 read the feeds, save new posts, send them to Supabase
    python rss.py upload FILE     send a file saved by an earlier run to Supabase

Shaqra University's feed (www.su.edu.sa/ar/rss.xml) is linked from no page; PROTOCOL.md says how
such feeds are found. Each post keeps the headline and the opening sentence, with the link to the
full article. The feed also names the editor who published it; that is never kept.
"""

import argparse
import html
import re
import sys
import time
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime

import collect

LEAD_LENGTH = 280  # characters of the article's opening kept under the headline
BIDI_MARKS = re.compile("[‎‏‪-‮⁦-⁩]")


# ---------------------------------------------------------------------------
# Reading a feed (no network, so these can be tested on their own)
# ---------------------------------------------------------------------------

def plain(fragment):
    """Text of an HTML fragment: tags removed, entities and spaces tidied, direction marks dropped."""
    text = re.sub(r"<(br|/p|/div)[^>]*>", "\n", fragment or "", flags=re.I)
    text = html.unescape(re.sub(r"<[^>]+>", " ", text))
    text = BIDI_MARKS.sub("", text).replace("\xa0", " ")
    return "\n".join(" ".join(line.split()) for line in text.splitlines() if line.strip())


def lead(description):
    """The opening of the article in a Drupal feed item: the part after its "محتوى" (content) label,
    without the headline, editor and date the item repeats before it."""
    parts = re.split(r"<div>\s*محتوى\s*</div>", description or "", maxsplit=1)
    return shorten(plain(parts[-1] if len(parts) == 2 else ""))


def shorten(text):
    """Text on one line, cut at the end of a sentence when it is longer than LEAD_LENGTH."""
    text = " ".join(text.split())
    if len(text) <= LEAD_LENGTH:
        return text
    cut = text[:LEAD_LENGTH]
    end = max(cut.rfind("."), cut.rfind("،"), cut.rfind("؛"))
    return cut[:end + 1] if end > LEAD_LENGTH // 2 else cut[:cut.rfind(" ")] + "…"


def items(feed_xml):
    """The feed's posts, newest first: link, headline, opening and time."""
    found = []
    for item in ET.fromstring(feed_xml).iter("item"):
        title = " ".join(plain(item.findtext("title")).split())
        link = (item.findtext("link") or "").strip()
        if not title or not link.startswith("http"):
            continue
        published = item.findtext("pubDate")
        found.append({
            "link": link,
            "title": title,
            "lead": lead(item.findtext("description")),
            "posted_at": parsedate_to_datetime(published).isoformat() if published else None,
        })
    return sorted(found, key=lambda post: post["posted_at"] or "", reverse=True)


def body_of(item):
    if not item["lead"] or item["lead"].startswith(item["title"]):
        return item["lead"] or item["title"]
    return f"{item['title']}\n\n{item['lead']}"


def page_image(page_html):
    """The article's share picture (og:image) with its size when the page gives it."""
    def meta(name):
        match = re.search(rf'<meta[^>]+property="{name}"[^>]+content="([^"]+)"', page_html)
        return html.unescape(match.group(1)) if match else None
    url = meta("og:image")
    if not url or not url.startswith("https://"):
        return []
    width, height = meta("og:image:width"), meta("og:image:height")
    image = {"url": url, "alt": None}
    if width and height and width.isdigit() and height.isdigit():
        image.update(width=int(width), height=int(height))
    return [image]


# ---------------------------------------------------------------------------
# The run
# ---------------------------------------------------------------------------

def run():
    env = collect.read_env()
    feeds = collect.read("sources?platform=eq.rss&status=eq.collected"
                         "&select=source_id,organization_id,url", env)
    posts = []
    for feed in feeds:
        siblings = collect.read(f"sources?organization_id=eq.{feed['organization_id']}&select=source_id", env)
        ids = ",".join(str(row["source_id"]) for row in siblings)
        known = {row["source_url"] for row in
                 collect.read(f"news_items?source_id=in.({ids})&select=source_url", env)}
        _, raw = collect.fetch(feed["url"])
        found = items(raw)
        print(f"{feed['url']}: {len(found)} items")
        for item in found:
            time.sleep(1.5)  # one page at a time, at a reader's pace
            try:
                address, page = collect.fetch(item["link"])  # the feed links /node/123; the page has its real address
            except OSError as error:
                print(f"  skipped {item['link']} ({error})")
                continue
            if address in known or item["link"] in known:
                continue
            post = {"source": feed["url"], "url": address, "posted_at": item["posted_at"],
                    "text": body_of(item)}
            images = page_image(page.decode("utf-8", "replace"))
            if images:
                post["images"] = images
            posts.append(post)
            print(f"  new  {(item['posted_at'] or '')[:10]}  {item['title'][:60]}")
    if not posts:
        print("No new posts.")
        return
    send(collect.save(posts, "rss"))


def send(path):
    collect.upload(path, function="import_post", argument="p_post", script="rss.py")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command")
    upload_command = commands.add_parser("upload", help="send a saved file to Supabase")
    upload_command.add_argument("file")
    args = parser.parse_args()
    if args.command == "upload":
        send(args.file)
    else:
        run()


if __name__ == "__main__":
    sys.exit(main())
