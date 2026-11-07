"""Finds one event reported by several sources (the website, X, YouTube and the press) and makes it
one story, so the replies under the X post show on the website's and the newspapers' reports.

    python stories.py               group every post, save the stories, send them to Supabase
    python stories.py upload FILE   send a file saved by an earlier run to Supabase

Two posts of one institution are the same story when they were published within DAYS days of each
other and share most of their key words: the opening words without common words and without the
institution's own name. Two posts that both have replies stay apart, each with its own replies. A
story's main post, the one the app shows, has the most replies, then is official rather than a
press report, then is the longest. Run it after the other collectors.
"""

import argparse
import re
import sys
from datetime import datetime

import collect

DAYS = 3
KEY_WORDS = 25  # how many of a post's opening key words are compared
COMMON = set("""
في من على الي عن مع او ان انه هذا هذه ذلك تلك خلال بين حتي كما بعد قبل عبر ضمن لدي عند كل اي قد
لا ما لم لن هو هي هم تم يتم وقد ايضا حيث منذ نحو اكثر اقل غير بعض جميع لها له لهم بها به فيها عليه
عليها التي الذي الذين اللذين وذلك بذلك كذلك اطار شان بشان عام عامه حول اجل
معالي سعاده سمو امير رئيس مكلف برعايه رعايه بحضور حضور ممثله ممثلا
""".split())


# ---------------------------------------------------------------------------
# Comparing posts (no network, so these can be tested on their own)
# ---------------------------------------------------------------------------

def normalize(text):
    """Arabic letters in one spelling, without diacritics, links, hashtag marks or punctuation."""
    text = re.sub(r"https?://\S+", " ", text or "")
    text = re.sub("[ؐ-ًؚ-ٰٟۖ-ۭـ]", "", text)
    for letters, plain in (("أإآٱ", "ا"), ("ى", "ي"), ("ة", "ه"), ("ؤ", "و"), ("ئ", "ي")):
        text = re.sub(f"[{letters}]", plain, text)
    return re.sub(r"[\W_]+", " ", text.lower())


def stem(word):
    for prefix in ("وال", "بال", "كال", "فال", "لل", "ال"):
        if word.startswith(prefix) and len(word) - len(prefix) >= 3:
            return word[len(prefix):]
    return word[1:] if word.startswith("و") and len(word) >= 5 else word


def key_words(text, skip=frozenset()):
    """The post's opening key words, in order, once each."""
    found = []
    for word in normalize(text).split():
        word = stem(word)
        if (len(word) >= 3 and word not in COMMON and word not in skip and word not in found
                and not re.fullmatch(r"(19|20)\d\d", word)):
            found.append(word)
        if len(found) == KEY_WORDS:
            break
    return set(found)


def own_name(name_ar):
    """Words of an institution's name, which every one of its posts shares: وزارة التعليم also
    skips وزير, so "the minister" does not make two posts look alike."""
    return frozenset(key_words(name_ar) | key_words(name_ar.replace("وزارة", "وزير")))


def alike(a, b):
    shared = len(a & b)
    return shared >= 4 and shared >= 0.5 * min(len(a), len(b))


def when(post):
    return datetime.fromisoformat(post["published_at"])


def main_of(group):
    return max(group, key=lambda post: (post["reply_count"], post["source_type"] != "press",
                                        len(post["body"]), -post["news_id"]))


def stories(posts, names):
    """Groups of the same event, as lists of posts. names maps organization_id to its Arabic name."""
    words = {post["news_id"]: key_words(post["body"], own_name(names.get(post["organization_id"], "")))
             for post in posts}
    leader = {post["news_id"]: post["news_id"] for post in posts}
    members = {post["news_id"]: [post] for post in posts}

    def find(news_id):
        while leader[news_id] != news_id:
            news_id = leader[news_id]
        return news_id

    ordered = sorted(posts, key=when)
    for i, a in enumerate(ordered):
        for b in ordered[i + 1:]:
            if (when(b) - when(a)).days >= DAYS:
                break
            if a["organization_id"] != b["organization_id"] or not alike(words[a["news_id"]], words[b["news_id"]]):
                continue
            x, y = find(a["news_id"]), find(b["news_id"])
            if x == y or (any(p["reply_count"] for p in members[x]) and any(p["reply_count"] for p in members[y])):
                continue  # already one story, or both have their own replies
            leader[y] = x
            members[x] += members.pop(y)
    return list(members.values())


def changes(groups, links):
    """What to send to save_story: each story whose links changed, and {"main": id, "others": []}
    for each post that was in a story and now stands alone. links maps a copy to its main post."""
    wanted, sent = {}, []
    for group in groups:
        main = main_of(group)["news_id"]
        others = sorted(post["news_id"] for post in group if post["news_id"] != main)
        wanted.update({other: main for other in others})
        if others and any(links.get(other) != main for other in others):
            sent.append({"main": main, "others": others})
    in_stories = set(wanted) | set(wanted.values())
    for news_id in sorted(set(links) | set(links.values())):
        if news_id not in in_stories:
            sent.append({"main": news_id, "others": []})
    return sent


# ---------------------------------------------------------------------------
# Supabase and the run
# ---------------------------------------------------------------------------

def read_all(path, env):
    rows, offset = [], 0
    while True:
        page = collect.read(f"{path}&order=news_id&limit=1000&offset={offset}", env)
        rows += page
        if len(page) < 1000:
            return rows
        offset += 1000


def run():
    env = collect.read_env()
    names = {row["organization_id"]: row["name_ar"] or row["name"]
             for row in collect.read("organizations?select=organization_id,name,name_ar", env)}
    sources = {row["source_id"]: row for row in
               collect.read("sources?select=source_id,organization_id,source_type", env)}
    replies = {row["news_id"]: row["reply_count"] for row in read_all("news_cards?select=news_id,reply_count", env)}
    links = {row["news_id"]: row["main_news_id"] for row in read_all("story_links?select=news_id,main_news_id", env)}
    posts = [{"news_id": row["news_id"], "body": row["body"],
              "published_at": row["published_at"] or row["collected_at"],
              "organization_id": sources[row["source_id"]]["organization_id"],
              "source_type": sources[row["source_id"]]["source_type"],
              "reply_count": replies.get(row["news_id"], 0)}
             for row in read_all("news_items?select=news_id,source_id,body,published_at,collected_at", env)]
    groups = stories(posts, names)
    print(f"{len(posts)} posts make {len(groups)} stories; "
          f"{sum(len(group) > 1 for group in groups)} of them come from more than one source.")
    sent = changes(groups, links)
    if not sent:
        print("No changes.")
        return
    send(collect.save(sent, "stories"))


def send(path):
    collect.upload(path, function="save_story", argument="p_story", script="stories.py")


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
