"""Checks the RSS, press, YouTube, review and statistics readers without the network.
Run: python -m unittest test_sources.py"""

import unittest
from datetime import date, datetime, timezone

import press
import reviews
import rss
import stats
import youtube

FEED = """<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/"><channel><title>جامعة شقراء</title>
<item><title>جامعة ⁧‫شقراء‬⁩ تتقدم في التصنيف</title><link>https://www.su.edu.sa/ar/node/1407</link>
<description>&lt;span&gt;جامعة شقراء تتقدم في التصنيف&lt;/span&gt; &lt;span&gt;&lt;span&gt;editor_admin&lt;/span&gt;&lt;/span&gt;
&lt;div&gt;&lt;div&gt;محتوى&lt;/div&gt;&lt;div&gt;&lt;p&gt;&amp;nbsp;&lt;/p&gt;&lt;p&gt;حققت الجامعة تقدمًا في التصنيف العالمي. وتفاصيل أخرى.&lt;/p&gt;&lt;/div&gt;&lt;/div&gt;</description>
<pubDate>Thu, 01 Oct 2026 11:12:54 +0000</pubDate><dc:creator>editor_admin</dc:creator></item>
<item><title>فيديو اليوم الوطني</title><link>https://www.su.edu.sa/ar/node/1416</link>
<description>&lt;span&gt;فيديو اليوم الوطني&lt;/span&gt;</description><pubDate>Wed, 14 Oct 2026 11:18:31 +0000</pubDate></item>
</channel></rss>"""

APPLE = {"feed": {"entry": [
    {"im:name": {"label": "مدرستي"}},  # the app itself
    {"id": {"label": "11"}, "title": {"label": "ممتاز"}, "content": {"label": "سهل"}, "im:rating": {"label": "5"},
     "im:version": {"label": "1.44"}, "updated": {"label": "2026-10-27T11:14:54-07:00"},
     "author": {"name": {"label": "someone"}}},
    {"id": {"label": "12"}, "title": {"label": "x"}, "content": {"label": ""}, "im:rating": {"label": "1"},
     "updated": {"label": "2026-10-20T10:00:00-07:00"}},
    {"id": {"label": "13"}, "title": {"label": "سيئ"}, "content": {"label": "لا يفتح"}, "im:rating": {"label": "2"},
     "updated": {"label": "2026-10-19T10:00:00-07:00"}},
]}}


class ReadsAFeed(unittest.TestCase):
    def setUp(self):
        self.items = rss.items(FEED.encode("utf-8"))

    def test_newest_first_with_direction_marks_removed(self):
        self.assertEqual([item["link"][-4:] for item in self.items], ["1416", "1407"])
        self.assertEqual(self.items[1]["title"], "جامعة شقراء تتقدم في التصنيف")

    def test_the_post_keeps_the_headline_and_opening_but_not_the_editor(self):
        body = rss.body_of(self.items[1])
        self.assertEqual(body, "جامعة شقراء تتقدم في التصنيف\n\nحققت الجامعة تقدمًا في التصنيف العالمي. وتفاصيل أخرى.")
        self.assertNotIn("editor_admin", body)
        self.assertEqual(self.items[1]["posted_at"], "2026-10-01T11:12:54+00:00")

    def test_an_item_with_only_a_headline(self):
        self.assertEqual(rss.body_of(self.items[0]), "فيديو اليوم الوطني")

    def test_long_openings_stop_at_a_sentence(self):
        text = "جملة أولى قصيرة. " * 40
        self.assertTrue(rss.lead(f"<div>محتوى</div><p>{text}</p>").endswith("."))
        self.assertLessEqual(len(rss.lead(f"<div>محتوى</div><p>{text}</p>")), rss.LEAD_LENGTH)

    def test_share_picture(self):
        page = '<meta property="og:image" content="https://a.sa/p.jpg" /><meta property="og:image:width" content="800" />' \
               '<meta property="og:image:height" content="450" />'
        self.assertEqual(rss.page_image(page), [{"url": "https://a.sa/p.jpg", "alt": None, "width": 800, "height": 450}])
        self.assertEqual(rss.page_image("<html></html>"), [])


NEWS = """<?xml version="1.0" encoding="UTF-8"?><rss version="2.0"><channel>
<item><title>وزير التعليم يزور جامعة القصيم - صحيفة سبق الإلكترونية</title>
<link>https://news.google.com/rss/articles/A1?oc=5</link><pubDate>Sun, 20 Sep 2026 07:00:00 GMT</pubDate>
<source url="https://sabq.org">صحيفة سبق الإلكترونية</source></item>
<item><title>عام / وزير التعليم يفتتح ملتقى القطاع غير الربحي - وكالة الأنباء السعودية</title>
<link>https://news.google.com/rss/articles/A2?oc=5</link><pubDate>Wed, 21 Oct 2026 07:00:00 GMT</pubDate>
<source url="https://www.spa.gov.sa">وكالة الأنباء السعودية</source></item>
<item><title>وزير التعليم المصري يبحث التعاون - اليوم السابع</title>
<link>https://news.google.com/rss/articles/A3?oc=5</link><pubDate>Wed, 21 Oct 2026 07:00:00 GMT</pubDate>
<source url="https://www.youm7.com">اليوم السابع</source></item>
<item><title>مجلس شؤون التعليم العام يقرّ اللائحة - وزارة التعليم</title>
<link>https://news.google.com/rss/articles/A4?oc=5</link><pubDate>Mon, 02 Nov 2026 05:20:58 GMT</pubDate>
<source url="https://www.moe.gov.sa">وزارة التعليم</source></item>
<item><title>الهيئة تطلق برنامجًا جديدًا للطلاب - عكاظ</title>
<link>https://news.google.com/rss/articles/A5?oc=5</link><pubDate>Mon, 02 Nov 2026 05:20:58 GMT</pubDate>
<source url="https://www.okaz.com.sa">عكاظ</source></item>
<item><title>وزير التعليم السابق يتلقى لقاح كورونا - عكاظ</title>
<link>https://news.google.com/rss/articles/A6?oc=5</link><pubDate>Sun, 01 Aug 2021 07:00:00 GMT</pubDate>
<source url="https://www.okaz.com.sa">عكاظ</source></item>
</channel></rss>"""

SEARCH = ("https://news.google.com/search?q=%22%D9%88%D8%B2%D8%A7%D8%B1%D8%A9+%D8%A7%D9%84%D8%AA%D8%B9%D9%84%D9%8A%D9%85%22"
          "+OR+%22%D9%88%D8%B2%D9%8A%D8%B1+%D8%A7%D9%84%D8%AA%D8%B9%D9%84%D9%8A%D9%85%22&hl=ar&gl=SA&ceid=SA%3Aar")
NEWS_PAGE = "https://moe.gov.sa/ar/mediacenter/MOENews/Pages/default.aspx"


class ReadsThePress(unittest.TestCase):
    def test_the_search_names_and_one_feed_per_outlet(self):
        self.assertEqual(press.names_in(SEARCH), ["وزارة التعليم", "وزير التعليم"])
        feeds = press.feeds(SEARCH, NEWS_PAGE)
        self.assertEqual(len(feeds), len(press.OUTLETS) + 1)
        self.assertIn("site%3Amoe.gov.sa%2Far%2Fmediacenter%2FMOENews%2FPages", feeds[0])
        self.assertIn("site%3Asabq.org", "".join(feeds))
        self.assertEqual(press.news_section("https://www.su.edu.sa/ar/news"), "su.edu.sa/ar/news")

    def test_saudi_reports_naming_the_institution_and_its_own_news_pages(self):
        since = datetime(2026, 9, 18, tzinfo=timezone.utc)
        found = press.reports(NEWS.encode("utf-8"), press.names_in(SEARCH), NEWS_PAGE, since)
        self.assertEqual([(r["outlet"], r["title"]) for r in found], [
            (None, "مجلس شؤون التعليم العام يقرّ اللائحة"),
            ("واس", "وزير التعليم يفتتح ملتقى القطاع غير الربحي"),
            ("سبق", "وزير التعليم يزور جامعة القصيم"),
        ])  # Egypt's minister, a headline without the name and a 2021 report are left out
        self.assertEqual(found[0]["posted_at"], "2026-11-02T05:20:58+00:00")

    def test_outlets_by_address(self):
        self.assertEqual(press.outlet_for("https://www.alriyadh.com"), "الرياض")
        self.assertIsNone(press.outlet_for("https://twaslnews1.twaslnews.com"))

    def test_the_ministry_also_gets_one_study_search_per_outlet(self):
        feeds = press.feeds(SEARCH, NEWS_PAGE, study=True)
        self.assertEqual(len(feeds), len(press.OUTLETS) + len({**press.OUTLETS, **press.STUDY_OUTLETS}) + 1)
        self.assertIn("site%3Aslaati.com", "".join(feeds))
        self.assertNotIn("site%3Aslaati.com", "".join(press.feeds(SEARCH, NEWS_PAGE)))
        self.assertIn("%D8%AA%D8%B9%D9%84%D9%8A%D9%82+%D8%A7%D9%84%D8%AF%D8%B1%D8%A7%D8%B3%D8%A9", feeds[-1])  # تعليق الدراسة

    def test_regional_study_decisions_are_kept_for_the_ministry_only(self):
        since = datetime(2026, 10, 1, tzinfo=timezone.utc)
        names = press.names_in(SEARCH)
        self.assertEqual(press.reports(STUDY_NEWS.encode("utf-8"), names, NEWS_PAGE, since, now=STUDY_NOW), [])
        found = press.reports(STUDY_NEWS.encode("utf-8"), names, NEWS_PAGE, since, study=True, now=STUDY_NOW)
        self.assertEqual([(r["outlet"], r["title"]) for r in found], [
            ("صدى", "تعليم الرياض يعلن تعليق الدراسة الحضورية حتى الخميس"),
            ("سبق", "تعليم الرياض: تحويل الدراسة عن بُعد حتى الخميس"),
            ("عكاظ", "تعليق الدراسة الحضورية في مدارس جدة ورابغ غدًا"),
        ])  # Yemen's closures, a Madrasati outage, an unkept outlet, a tag page and a study-only
        #     paper's other news naming the Ministry are left out

    def test_old_study_decisions_are_not_news_any_more(self):
        since = datetime(2026, 9, 1, tzinfo=timezone.utc)
        later = datetime(2026, 11, 20, tzinfo=timezone.utc)  # more than STUDY_DAYS after the reports
        found = press.reports(STUDY_NEWS.encode("utf-8"), press.names_in(SEARCH), NEWS_PAGE, since,
                              study=True, now=later)
        self.assertEqual(found, [])


STUDY_NOW = datetime(2026, 11, 4, 12, 0, tzinfo=timezone.utc)
STUDY_NEWS ="""<?xml version="1.0" encoding="UTF-8"?><rss version="2.0"><channel>
<item><title>تعليق الدراسة الحضورية في مدارس جدة ورابغ غدًا - عكاظ</title>
<link>https://news.google.com/rss/articles/S1?oc=5</link><pubDate>Sat, 31 Oct 2026 19:00:00 GMT</pubDate>
<source url="https://www.okaz.com.sa">عكاظ</source></item>
<item><title>تعليم الرياض: تحويل الدراسة عن بُعد حتى الخميس - صحيفة سبق الإلكترونية</title>
<link>https://news.google.com/rss/articles/S2?oc=5</link><pubDate>Sun, 01 Nov 2026 06:00:00 GMT</pubDate>
<source url="https://sabq.org">صحيفة سبق الإلكترونية</source></item>
<item><title>لجنة الطوارئ بتعز تجدد تعليق الدراسة - عكاظ</title>
<link>https://news.google.com/rss/articles/S3?oc=5</link><pubDate>Sun, 01 Nov 2026 07:00:00 GMT</pubDate>
<source url="https://www.okaz.com.sa">عكاظ</source></item>
<item><title>عطل مفاجئ في منصة مدرستي - عاجل</title>
<link>https://news.google.com/rss/articles/S4?oc=5</link><pubDate>Sun, 01 Nov 2026 08:00:00 GMT</pubDate>
<source url="https://ajel.sa">عاجل</source></item>
<item><title>تعليق الدراسة في الرياض حتى الخميس - المصري اليوم</title>
<link>https://news.google.com/rss/articles/S5?oc=5</link><pubDate>Sun, 01 Nov 2026 09:00:00 GMT</pubDate>
<source url="https://www.almasryalyoum.com">المصري اليوم</source></item>
<item><title>تعليم الرياض يعلن تعليق الدراسة الحضورية حتى الخميس - صحيفة صدى الالكترونية</title>
<link>https://news.google.com/rss/articles/S6?oc=5</link><pubDate>Sun, 01 Nov 2026 10:00:00 GMT</pubDate>
<source url="https://slaati.com">صحيفة صدى الالكترونية</source></item>
<item><title>وزير التعليم السابق يزور جامعة تورنتو - صحيفة صدى الالكترونية</title>
<link>https://news.google.com/rss/articles/S7?oc=5</link><pubDate>Sun, 01 Nov 2026 11:00:00 GMT</pubDate>
<source url="https://slaati.com">صحيفة صدى الالكترونية</source></item>
<item><title>تعليق-الدراسة - عكاظ</title>
<link>https://news.google.com/rss/articles/S8?oc=5</link><pubDate>Sun, 01 Nov 2026 12:00:00 GMT</pubDate>
<source url="https://www.okaz.com.sa">عكاظ</source></item>
</channel></rss>"""


FEED_ATOM = """<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns:yt="http://www.youtube.com/xml/schemas/2015" xmlns:media="http://search.yahoo.com/mrss/" xmlns="http://www.w3.org/2005/Atom">
<entry><yt:videoId>8j10QBe4Mto</yt:videoId><title>جدول الاختبارات في نظام نور</title>
<published>2026-10-23T05:37:07+00:00</published><media:group><media:title>جدول الاختبارات في نظام نور</media:title>
<media:thumbnail url="https://i1.ytimg.com/vi/8j10QBe4Mto/hqdefault.jpg" width="480" height="360"/>
<media:description>طريقة الاطلاع على جدول الاختبارات.</media:description></media:group></entry>
<entry><yt:videoId>RD9_zEFb2tc</yt:videoId><title>المعلم.. أثر.‫ #يوم_المعلم</title>
<published>2026-10-05T07:14:56+00:00</published><media:group><media:description></media:description></media:group></entry>
</feed>"""


class ReadsYouTube(unittest.TestCase):
    def test_feed_addresses(self):
        self.assertEqual(youtube.feed_url("https://www.youtube.com/channel/UCNI3mOncSgbjIJJp01EzgVA"),
                         "https://www.youtube.com/feeds/videos.xml?channel_id=UCNI3mOncSgbjIJJp01EzgVA")
        self.assertEqual(youtube.feed_url("https://www.youtube.com/user/shaqrauniv"),
                         "https://www.youtube.com/feeds/videos.xml?user=shaqrauniv")
        self.assertIsNone(youtube.feed_url("https://www.youtube.com/@moe"))

    def test_videos_with_their_picture_and_description(self):
        found = youtube.videos(FEED_ATOM.encode("utf-8"))
        self.assertEqual([v["id"] for v in found], ["8j10QBe4Mto", "RD9_zEFb2tc"])
        self.assertEqual(found[0]["link"], "https://www.youtube.com/watch?v=8j10QBe4Mto")
        self.assertEqual(found[0]["images"][0]["width"], 480)
        self.assertEqual(youtube.body_of(found[0]), "جدول الاختبارات في نظام نور\n\nطريقة الاطلاع على جدول الاختبارات.")
        self.assertEqual(youtube.body_of(found[1]), "المعلم.. أثر. #يوم_المعلم")

    def test_comments_keep_no_author(self):
        answer = {"items": [{"id": "c1", "snippet": {"topLevelComment": {"snippet": {
            "textOriginal": "  متى  النتائج؟ ", "likeCount": 3, "publishedAt": "2026-10-23T08:00:00Z",
            "authorDisplayName": "someone"}}}}]}
        self.assertEqual(youtube.comments_in(answer),
                         [{"id": "c1", "text": "متى النتائج؟", "posted_at": "2026-10-23T08:00:00Z", "likes": 3}])


class ReadsAppReviews(unittest.TestCase):
    def test_reviews_with_words_get_a_face_from_their_stars_and_no_author(self):
        found = reviews.reviews_in(APPLE, "https://apps.apple.com/sa/app/id1")
        self.assertEqual([r["id"] for r in found], ["11", "13"])
        self.assertEqual(found[0], {"source": "https://apps.apple.com/sa/app/id1", "id": "11", "title": "ممتاز",
                                    "text": "سهل", "rating": 5, "version": "1.44",
                                    "posted_at": "2026-10-27T11:14:54-07:00", "emotion": "happy",
                                    "emotion_by": "stars"})
        self.assertEqual(found[1]["emotion"], "sad")
        self.assertNotIn("someone", str(found))


class MakesStatistics(unittest.TestCase):
    def test_hijri_year(self):
        self.assertEqual(stats.hijri_year(date(2026, 11, 1)), 1448)
        self.assertEqual(stats.hijri_year(date(2025, 7, 1)), 1447)

    def test_bars_are_largest_first_and_the_rest_is_added_up(self):
        self.assertEqual(stats.bars({"أ": 1, "ب": 5, "ج": 0, " د ": 3}, top=2),
                         [{"label": "ب", "value": 5}, {"label": "د", "value": 3}, {"label": "أخرى", "value": 1}])

    def test_faculty(self):
        members = [{"gender": "أنثى", "grade": "محاضر", "universityCountry": "بريطانيا"},
                   {"gender": "ذكر", "grade": "Lecturer", "universityCountry": "المملكة العربية السعودية"},
                   {"gender": "أنثى", "grade": "استاذ", "universityCountry": ""}]
        found = {row["label"]: row for row in stats.faculty_stats(members, "https://o.sa/f", "2026")}
        self.assertEqual(found["أعضاء هيئة التدريس"]["breakdown"],
                         [{"label": "محاضر", "value": 2}, {"label": "استاذ", "value": 1}])
        self.assertEqual(found["أعضاء هيئة التدريس من خريجي جامعات خارج المملكة"]["value"], 50.0)

    def test_blackboard_keeps_the_figures_shown_in_the_app(self):
        answer = {"blackboardStatisticsList": [{"title": "عدد الطلاب", "count": 19111},
                                               {"title": "عدد الأدلة الإرشادية", "count": 20}]}
        found = stats.blackboard_stats(answer, "https://o.sa/b", "1445هـ")
        self.assertEqual([(row["label"], row["value"]) for row in found], [("الطلاب في نظام بلاك بورد", 19111)])

    def test_app_rating_does_not_repeat_the_word_app(self):
        app = {"name": "تطبيق جامعة شقراء", "url": "https://apps.apple.com/sa/app/id1", "organization": "Shaqra University"}
        row = stats.app_rating(app, {"results": [{"averageUserRating": 3.72642, "userRatingCount": 106}]}, date(2026, 11, 1))
        self.assertEqual((row["label"], row["value"], row["unit"], row["period"]),
                         ("تقييم تطبيق جامعة شقراء في App Store", 3.73, "/5", "2026-11"))
        self.assertIsNone(stats.app_rating(app, {"results": []}, date(2026, 11, 1)))


if __name__ == "__main__":
    unittest.main()
