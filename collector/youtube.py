"""Collects institutions' YouTube videos: every source with platform 'youtube' and status 'collected'.

    python youtube.py               read the channels' feeds, save new videos, send them to Supabase
    python youtube.py upload FILE   send a file saved by an earlier run to Supabase

Each channel's public feed (youtube.com/feeds/videos.xml) lists its latest 15 videos with the
title, description, picture and time. With YOUTUBE_API_KEY in collector/.env it also reads the
most relevant public comments under each video through the YouTube Data API, keeping only their
text, time and likes, never who wrote them. Without the key the videos come without comments.
"""

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import xml.etree.ElementTree as ET

import collect
from rss import plain, shorten

NS = {"atom": "http://www.w3.org/2005/Atom", "media": "http://search.yahoo.com/mrss/",
      "yt": "http://www.youtube.com/xml/schemas/2015"}
MOST_COMMENTS = 100  # per video, most relevant first (one page of the API)


# ---------------------------------------------------------------------------
# Reading a feed and comments (no network, so these can be tested on their own)
# ---------------------------------------------------------------------------

def feed_url(channel_url):
    """The public feed of a channel address (/channel/ID or /user/NAME), or None."""
    parts = urllib.parse.urlparse(channel_url).path.strip("/").split("/")
    if len(parts) == 2 and parts[0] in ("channel", "user"):
        key = "channel_id" if parts[0] == "channel" else "user"
        return f"https://www.youtube.com/feeds/videos.xml?{key}={parts[1]}"
    return None


def videos(feed_xml):
    """The feed's videos, newest first: id, link, title, description, picture and time."""
    found = []
    for entry in ET.fromstring(feed_xml).findall("atom:entry", NS):
        video_id = entry.findtext("yt:videoId", namespaces=NS)
        title = " ".join(plain(entry.findtext("atom:title", namespaces=NS)).split())
        if not video_id or not title:
            continue
        group = entry.find("media:group", NS)
        picture = group.find("media:thumbnail", NS) if group is not None else None
        video = {"id": video_id, "link": f"https://www.youtube.com/watch?v={video_id}", "title": title,
                 "description": (group.findtext("media:description", namespaces=NS) or "") if group is not None else "",
                 "posted_at": entry.findtext("atom:published", namespaces=NS), "images": []}
        if picture is not None and (picture.get("url") or "").startswith("https://"):
            video["images"] = [{"url": picture.get("url"), "alt": title,
                                "width": int(picture.get("width", 480)), "height": int(picture.get("height", 360))}]
        found.append(video)
    return sorted(found, key=lambda video: video["posted_at"] or "", reverse=True)


def body_of(video):
    description = shorten(plain(video["description"]))
    if not description or description.startswith(video["title"]):
        return description or video["title"]
    return f"{video['title']}\n\n{description}"


def comments_in(answer):
    """Public comments in a commentThreads answer: text, time and likes only."""
    found = []
    for thread in answer.get("items", []):
        comment = thread.get("snippet", {}).get("topLevelComment", {}).get("snippet", {})
        text = " ".join((comment.get("textOriginal") or comment.get("textDisplay") or "").split())
        if text and thread.get("id"):
            found.append({"id": thread["id"], "text": text, "posted_at": comment.get("publishedAt"),
                          "likes": comment.get("likeCount", 0)})
    return found


# ---------------------------------------------------------------------------
# The run
# ---------------------------------------------------------------------------

def comments(video_id, key):
    query = urllib.parse.urlencode({"part": "snippet", "videoId": video_id, "maxResults": MOST_COMMENTS,
                                    "order": "relevance", "textFormat": "plainText", "key": key})
    try:
        _, raw = collect.fetch("https://www.googleapis.com/youtube/v3/commentThreads?" + query)
    except urllib.error.HTTPError as error:
        if error.code == 403:  # comments turned off for this video, or the key's daily quota used up
            return []
        raise
    return comments_in(json.loads(raw))


def run():
    env = collect.read_env()
    key = env.get("YOUTUBE_API_KEY")
    if not key:
        print("No YOUTUBE_API_KEY in collector/.env: videos are collected without their comments.")
    channels = collect.read("sources?platform=eq.youtube&status=eq.collected&select=url", env)
    posts = []
    for channel in channels:
        address = feed_url(channel["url"])
        if not address:
            print(f"{channel['url']}: no public feed for this kind of address")
            continue
        _, raw = collect.fetch(address)
        found = videos(raw)
        print(f"{channel['url']}: {len(found)} videos")
        for video in found:
            post = {"source": channel["url"], "url": video["link"], "posted_at": video["posted_at"],
                    "text": body_of(video), "images": video["images"]}
            if key:
                time.sleep(0.5)
                post["replies"] = comments(video["id"], key)
            posts.append(post)
            print(f"  {(video['posted_at'] or '')[:10]}  {len(post.get('replies', [])):3} comments  {video['title'][:60]}")
    if not posts:
        print("No videos.")
        return
    send(collect.save(posts, "youtube"))


def send(path):
    collect.upload(path, function="import_post", argument="p_post", script="youtube.py")


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
