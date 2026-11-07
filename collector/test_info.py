"""Checks what people ask about and the Info page, without the network. Run: python -m unittest test_info.py"""

import json
import unittest
from datetime import date, datetime, timezone

import info
import topics

NOW = datetime(2026, 11, 4, 12, 0, tzinfo=timezone.utc)


class CountsWhatPeopleAsk(unittest.TestCase):
    def test_real_replies(self):
        self.assertEqual(topics.asks("علقووووو"), ["status"])
        self.assertEqual(topics.asks("فيه دوام ولا بكره"), ["status"])
        self.assertEqual(topics.asks("هل الدراسه عن بعد؟؟؟"), ["status"])
        self.assertEqual(topics.asks("متى تبدأ إجازة الخريف؟"), ["dates"])
        self.assertEqual(topics.asks("عمادة القبول ليش ماترد على الايميل؟"), ["help"])
        self.assertEqual(topics.asks("مدرستي معلق مادخل الطلاب للحين!!!!"), ["apps"])
        self.assertEqual(topics.asks("مبادرة رائعة من جامعة شقراء! نتمنى لكم التوفيق"), [])

    def test_words_that_only_look_alike(self):
        self.assertEqual(topics.asks("السلام عليكم لدي مشكله في دوام طفل ابتدائي وقت خروج ١:٣٥"), [])
        self.assertEqual(topics.asks("اللائحة تنظم التعليم الخاص"), [])
        self.assertEqual(topics.asks("نور الله قلبك"), [])

    def test_a_text_posted_many_times_counts_once(self):
        counts = topics.asked_counts(["نبي تعليق بكره", "نبي تعليق بكره", "علقو", "كيف أتواصل مع الجامعة"])
        self.assertEqual(counts, {"status": 2, "dates": 0, "help": 1, "apps": 0})

    def test_most_asked_first_and_the_numbers_last(self):
        self.assertEqual(topics.order({"status": 2, "dates": 5, "help": 5, "apps": 1}),
                         ["dates", "help", "status", "apps", "numbers"])
        self.assertEqual(topics.order({}), ["status", "dates", "help", "apps", "numbers"])


class FindsStudyAnnouncements(unittest.TestCase):
    def test_saudi_decisions_on_study(self):
        for headline in ["تعليم الرياض يقرر تحويل الدراسة عن بُعد حتى الخميس",
                         "السعودية تعلق الدراسة الحضورية في 9 مدن ومناطق حتى الخميس",
                         "تعليم الطائف.. استمرار الدراسة “عن بُعد” حتى 25 جمادى الأولى",
                         "جامعة شقراء تعلن استئناف الدراسة الحضورية يوم الأحد"]:
            self.assertTrue(topics.about_study(headline), headline)

    def test_other_countries_and_other_news(self):
        for headline in ["لجنة الطوارئ بتعز: استمرار تعليق الدراسة في مديريات سيطرة الحوثي",
                         "فيضانات تضرب دير الزور.. وتعليق الدراسة",
                         "عطل مفاجئ في منصة مدرستي ومعلمون يشتكون",
                         "وزير التعليم يبحث تعزيز الشراكة السعودية التركية"]:
            self.assertFalse(topics.about_study(headline), headline)


def card(body, when, source="سبق", url="https://news.google.com/rss/articles/A"):
    return {"body": body, "published_at": when, "source_name": source, "source_url": url}


class WritesTheInfoPage(unittest.TestCase):
    def test_the_newest_study_posts_of_the_week_once_each(self):
        cards = [
            card("تعليق الدراسة الحضورية في مدارس جدة غدًا", "2026-11-01T19:00:00+00:00", url="https://x.com/a/status/1#preview-1"),
            card("تعليق الدراسة الحضورية في مدارس جدة غدًا", "2026-11-01T20:00:00+00:00", "عكاظ"),
            card("وزير التعليم يفتتح ملتقى", "2026-11-03T08:00:00+00:00"),
            card("تحويل الدراسة عن بُعد في الرياض حتى الخميس\nالتفاصيل", "2026-11-03T09:00:00+00:00", "واس"),
            card("تعليق الدراسة في مدارس تبوك", "2026-10-20T09:00:00+00:00"),  # older than a week
        ]
        found = info.status_items(cards, NOW)
        self.assertEqual([(item["source_name"], item["title"]) for item in found], [
            ("واس", "تحويل الدراسة عن بُعد في الرياض حتى الخميس"),
            ("عكاظ", "تعليق الدراسة الحضورية في مدارس جدة غدًا"),
        ])
        self.assertEqual(found[0]["published_at"], "2026-11-03T09:00:00+00:00")

    def test_links_lose_their_preview_marker(self):
        found = info.status_items([card("تعليق الدراسة غدًا", "2026-11-03T09:00:00+00:00",
                                        url="https://x.com/a/status/1#preview-1")], NOW)
        self.assertEqual(found[0]["link"], "https://x.com/a/status/1")
        self.assertEqual(found[0]["source_url"], "https://x.com/a/status/1")

    def test_long_posts_are_cut_at_a_word(self):
        title = info.headline("كلمة " * 80)
        self.assertLessEqual(len(title), info.TITLE_LENGTH + 1)
        self.assertTrue(title.endswith("كلمة…"))

    def test_only_dates_that_have_not_ended(self):
        items = [{"title": "b", "starts_on": "2026-12-20"}, {"title": "a", "starts_on": "2026-11-01"},
                 {"title": "now", "starts_on": "2026-11-01", "ends_on": "2026-11-05"},
                 {"title": "today", "starts_on": "2026-11-04"}]
        self.assertEqual([item["title"] for item in info.upcoming(items, date(2026, 11, 4))], ["now", "today", "b"])

    def test_sections_most_asked_first(self):
        written = {"dates": {"note": "ملاحظة", "items": [{"title": "إجازة", "starts_on": "2027-01-08"}]},
                   "help": {"items": [{"title": "تواصل", "link": "tel:19996"}]}}
        status = [{"title": "تعليق الدراسة"}]
        found = info.sections("Shaqra University", {"status": 1, "dates": 0, "help": 3, "apps": 0},
                              status, written, date(2026, 11, 4))
        self.assertEqual([(s["kind"], s["position"], s["asked"]) for s in found],
                         [("help", 1, 3), ("status", 2, 1), ("dates", 3, 0), ("apps", 4, 0), ("numbers", 5, 0)])
        self.assertEqual(found[1]["items"], status)
        self.assertEqual(found[2]["note"], "ملاحظة")
        self.assertNotIn("items", found[3])  # apps and numbers keep what reviews.py and stats.py wrote

    def test_without_the_study_status(self):
        found = info.sections("Shaqra University", {}, [], {}, date(2026, 11, 4), with_status=False)
        self.assertEqual([s["kind"] for s in found], ["dates", "help", "apps", "numbers"])
        self.assertEqual(found[0]["items"], [])

    def test_the_written_files_have_their_sources(self):
        written = info.by_hand()
        self.assertEqual(set(written), {"Ministry of Education", "Shaqra University"})
        for name, page in written.items():
            for kind in ("dates", "help"):
                for item in page[kind]["items"]:
                    self.assertTrue(item["source_url"].startswith("https://"), (name, item))
                    self.assertTrue(item["title"].strip(), (name, item))
                    if kind == "dates":
                        start = date.fromisoformat(item["starts_on"])
                        self.assertLessEqual(start, date.fromisoformat(item.get("ends_on") or item["starts_on"]))
                    else:
                        self.assertRegex(item["link"], r"^(https://|tel:|mailto:)")

    def test_times_for_a_query_have_no_plus(self):
        self.assertEqual(info.stamp(NOW), "2026-11-04T12:00:00Z")


class SendsTheSections(unittest.TestCase):
    def test_a_saved_file_goes_to_save_info_section(self):
        sent = []
        original = info.collect.upload
        info.collect.upload = lambda path, function, argument, script: sent.append((path, function, argument))
        try:
            info.send("info-1.json")
        finally:
            info.collect.upload = original
        self.assertEqual(sent, [("info-1.json", "save_info_section", "p_section")])

    def test_sections_are_plain_json(self):
        found = info.sections("Ministry of Education", {}, [], info.by_hand()["Ministry of Education"],
                              date(2026, 11, 4))
        self.assertEqual(json.loads(json.dumps(found, ensure_ascii=False)), found)


if __name__ == "__main__":
    unittest.main()
