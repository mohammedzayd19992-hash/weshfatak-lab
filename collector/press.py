"""Collects what SPA and the Saudi press report about each institution: every source with platform
'media' and status 'collected', read from Google News.

    python press.py                 read the searches, save new reports, send them to Supabase
    python press.py upload FILE     send a file saved by an earlier run to Supabase

Each source's address is a Google News search for the institution's names in quotes. The collector
reads that search once for each outlet in OUTLETS and keeps a report when its headline names the
institution. It also reads Google's list of the pages in the institution's website news section:
the Ministry's news pages are given out by its website only through an internal SharePoint API, so
this is how they arrive, saved under the website source. Only the headline, the outlet, the time
and the link are kept.

For the Ministry it also searches each outlet for study being suspended, moved online or back in
person. Those decisions are announced region by region ("تعليم الرياض: تحويل الدراسة عن بعد"), so
their headlines rarely name the Ministry, and they are what people ask under its posts most. They
are kept when topics.about_study says the headline is about study in Saudi Arabia.
"""

import argparse
import re
import sys
import time
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from urllib.parse import parse_qs, urlencode, urlparse

import collect
import topics
from rss import plain

DAYS = 45  # reports older than this are left out; Google ignores "when:" in a search by site
STUDY_SEARCH = ('("تعليق الدراسة" OR "الدراسة عن بعد" OR "الدراسة عن بُعد" OR "الدراسة الحضورية"'
                ' OR "منصة مدرستي")')

OUTLETS = {  # Saudi news outlets whose reports are kept, by address, with the short name shown
    "spa.gov.sa": "واس",
    "sabq.org": "سبق",
    "okaz.com.sa": "عكاظ",
    "al-madina.com": "المدينة",
    "alriyadh.com": "الرياض",
    "al-jazirah.com": "الجزيرة",
    "alyaum.com": "اليوم",
    "alwatan.com.sa": "الوطن",
    "makkahnewspaper.com": "مكة",
    "ajel.sa": "عاجل",
    "argaam.com": "أرقام",
    "almowaten.net": "المواطن",
    "alekhbariya.net": "الإخبارية",
    "aawsat.com": "الشرق الأوسط",
    "alarabiya.net": "العربية",
    "arabnews.com": "Arab News",
    "saudigazette.com.sa": "Saudi Gazette",
}
# Left out after checking: twaslnews.com (mostly Egyptian news) and alshaamal.com (old reports
# that Google dates as new).
STUDY_OUTLETS = {  # Saudi e-papers kept only for decisions on study, not for other news
    "slaati.com": "صدى",
    "sra7h.com": "صراحة",
    "shahdnow.sa": "شاهد الآن",
    "al-marsd.com": "المرصد",
}
# Added on 4 November 2026: the regional decisions to move study online during the alerts of 1 to
# 5 November reached these papers and not the larger ones. Their other news is mostly gossip.
STUDY_DAYS = 10  # a decision on study kept only for being about study is news for this long


# ---------------------------------------------------------------------------
# Reading a search feed (no network, so these can be tested on their own)
# ---------------------------------------------------------------------------

def host(url):
    name = urlparse(url or "").netloc.lower()
    return name[4:] if name.startswith("www.") else name


def outlet_for(url, outlets=None):
    """The short name of a kept outlet, or None."""
    name = host(url)
    return next((short for address, short in (outlets or OUTLETS).items()
                 if name == address or name.endswith("." + address)), None)


def names_in(search_url):
    """The quoted names a search looks for: '"وزارة التعليم" OR "وزير التعليم"' gives both."""
    query = parse_qs(urlparse(search_url).query).get("q", [""])[0]
    return re.findall(r'"([^"]+)"', query)


def news_section(website_url):
    """moe.gov.sa/ar/mediacenter/MOENews/Pages for .../MOENews/Pages/default.aspx: the folder of
    the website's news page, so Google lists its news and not every page of the site."""
    path = urlparse(website_url).path.rstrip("/")
    if "." in path.rsplit("/", 1)[-1]:
        path = path.rsplit("/", 1)[0]
    return host(website_url) + path


def feeds(search_url, website_url=None, study=False):
    """Google News feeds to read: the website's news section first, then the search per outlet, then
    (for the Ministry) the search per outlet for study being suspended or moved online."""
    def feed(query):
        return "https://news.google.com/rss/search?" + urlencode(
            {"q": f"{query} when:{DAYS}d", "hl": "ar", "gl": "SA", "ceid": "SA:ar"})
    names = names_in(search_url)
    wanted = " OR ".join(f'"{name}"' for name in names)
    if len(names) > 1:
        wanted = f"({wanted})"
    own = [feed(f"site:{news_section(website_url)}")] if website_url else []
    about_study = [feed(f"{STUDY_SEARCH} site:{site}") for site in {**OUTLETS, **STUDY_OUTLETS}] if study else []
    return own + [feed(f"{wanted} site:{site}") for site in OUTLETS] + about_study


def headline(title, outlet, spa=False):
    """The headline without the " - outlet" Google adds, and for SPA without its section
    ("عام / ", "علوم وتقنيات / ")."""
    title = " ".join(plain(title).split())
    if outlet and title.endswith(" - " + outlet):
        title = title[: -len(outlet) - 3]
    title = re.sub(r"\s+copy$", "", title)  # the Ministry's pages copied from a template keep the word
    return (re.sub(r"^[^/]{1,25} / ", "", title) if spa else title).strip()


def a_headline(title):
    """False for the tag and archive pages Google lists among reports ("تعليق-الدراسة - عكاظ",
    "إنذار أحمر الأرشيف", "الوسم: ...")."""
    return len(title.split()) >= 4 and not title.endswith("الأرشيف") and not title.startswith("الوسم")


def reports(feed_xml, names, website_url, since, study=False, now=None):
    """Reports in a search feed since a time, newest first: link, headline, outlet (None for the
    institution's own website) and time. Only kept outlets, and only headlines naming the
    institution, or with study=True headlines of the last STUDY_DAYS days about study being
    suspended, moved online or back in person."""
    study_since = max(since, (now or datetime.now(timezone.utc)) - timedelta(days=STUDY_DAYS))
    found = []
    for item in ET.fromstring(feed_xml).iter("item"):
        source = item.find("source")
        address = source.get("url") if source is not None else ""
        own = bool(website_url) and host(address) == host(website_url)
        outlet = None if own else outlet_for(address)
        study_only = not own and not outlet and study and outlet_for(address, STUDY_OUTLETS)
        outlet = outlet or study_only or None
        title = headline(item.findtext("title"), source.text if source is not None else None,
                         spa=outlet == OUTLETS["spa.gov.sa"])
        link = (item.findtext("link") or "").strip()
        published = item.findtext("pubDate")
        posted_at = parsedate_to_datetime(published) if published else None
        if not (own or outlet) or not link.startswith("https://") or not posted_at or posted_at < since:
            continue
        named = (own or any(name in title for name in names)) and not study_only
        about_study = (study and posted_at >= study_since and a_headline(title)
                       and topics.about_study(title))
        if not named and not about_study:
            continue  # a report that only mentions the institution further down
        found.append({"link": link, "title": title, "outlet": outlet, "posted_at": posted_at.isoformat()})
    return sorted(found, key=lambda report: report["posted_at"], reverse=True)


# ---------------------------------------------------------------------------
# The run
# ---------------------------------------------------------------------------

def run():
    env = collect.read_env()
    searches = collect.read("sources?platform=eq.media&status=eq.collected"
                            "&select=organization_id,url", env)
    since = datetime.now(timezone.utc) - timedelta(days=DAYS)
    posts = []
    for search in searches:
        org = search["organization_id"]
        website = collect.read(f"sources?organization_id=eq.{org}&platform=eq.website&role=eq.news"
                               "&order=source_id&limit=1&select=url", env)
        website_url = website[0]["url"] if website else None
        kind = collect.read(f"organizations?organization_id=eq.{org}&select=kind", env)
        study = bool(kind) and kind[0]["kind"] == "ministry"  # regional study decisions are the Ministry's news
        siblings = collect.read(f"sources?organization_id=eq.{org}&select=source_id", env)
        ids = ",".join(str(row["source_id"]) for row in siblings)
        known = {row["source_url"] for row in
                 collect.read(f"news_items?source_id=in.({ids})&select=source_url", env)}
        found = {}
        for feed in feeds(search["url"], website_url, study):
            time.sleep(1.5)  # one search at a time, at a reader's pace
            _, raw = collect.fetch(feed)
            for report in reports(raw, names_in(search["url"]), website_url, since, study):
                found.setdefault(report["link"], report)
        print(f"{names_in(search['url'])}: {len(found)} reports in {DAYS} days")
        for report in sorted(found.values(), key=lambda report: report["posted_at"], reverse=True):
            if report["link"] in known:
                continue
            post = {"source": website_url if report["outlet"] is None else search["url"],
                    "url": report["link"], "posted_at": report["posted_at"], "text": report["title"]}
            if report["outlet"]:
                post["outlet"] = report["outlet"]
            posts.append(post)
            print(f"  new  {(report['posted_at'] or '')[:10]}  {report['outlet'] or 'website'}  {report['title'][:60]}")
    if not posts:
        print("No new reports.")
        return
    send(collect.save(posts, "press"))


def send(path):
    collect.upload(path, function="import_post", argument="p_post", script="press.py")


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
