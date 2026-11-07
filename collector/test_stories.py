"""Checks how stories.py finds one event reported by several sources. Run: python -m unittest test_stories.py"""

import unittest

import stories

NAMES = {31: "وزارة التعليم"}


def post(news_id, body, day, replies=0, kind="social"):
    return {"news_id": news_id, "body": body, "published_at": f"2026-10-{day:02d}T10:00:00+00:00",
            "organization_id": 31, "source_type": kind, "reply_count": replies}


TURKEY_X = post(1, "#وزير_التعليم يبحث تعزيز الشراكة السعودية التركية، وتوسيع مجالات التعاون التعليمي والأكاديمي والبحثي.",
                27, replies=3)
TURKEY_SPA = post(2, "وزير التعليم يبحث تعزيز الشراكة السعودية التركية وتوسيع مجالات التعاون التعليمي والأكاديمي والبحثي",
                  27, kind="press")
TURKEY_SITE = post(3, "وزير التعليم يبحث تعزيز الشراكة السعودية التركية وتوسيع مجالات التعاون", 28, kind="website")
OTHER = post(4, "الكشف المبكر يرفع فرص الشفاء والتعافي. #شهر_التوعية_بسرطان_الثدي", 27, replies=5)


class FindsStories(unittest.TestCase):
    def test_spellings_and_the_institution_name_do_not_count(self):
        self.assertEqual(stories.normalize("أكاديميّة"), "اكاديميه")
        words = stories.key_words("وزارة التعليم تطلق مبادرة #مدرستي_الأولى", stories.own_name("وزارة التعليم"))
        self.assertEqual(words, {"تطلق", "مبادره", "مدرستي", "اولي"})

    def test_one_event_from_x_the_press_and_the_website_is_one_story(self):
        groups = stories.stories([TURKEY_X, TURKEY_SPA, TURKEY_SITE, OTHER], NAMES)
        together = next(group for group in groups if len(group) > 1)
        self.assertEqual(sorted(p["news_id"] for p in together), [1, 2, 3])
        self.assertEqual(stories.main_of(together)["news_id"], 1)  # the one with the replies
        self.assertEqual(len(groups), 2)

    def test_two_posts_with_their_own_replies_stay_apart(self):
        again = dict(TURKEY_SPA, news_id=5, source_type="social", reply_count=13)
        self.assertEqual(len(stories.stories([TURKEY_X, again], NAMES)), 2)

    def test_posts_days_apart_stay_apart(self):
        later = dict(TURKEY_SPA, published_at="2026-10-31T10:00:00+00:00")
        self.assertEqual(len(stories.stories([TURKEY_X, later], NAMES)), 2)

    def test_only_changed_stories_are_sent_and_broken_ones_are_undone(self):
        groups = [[TURKEY_X, TURKEY_SPA, TURKEY_SITE], [OTHER]]
        self.assertEqual(stories.changes(groups, {}), [{"main": 1, "others": [2, 3]}])
        self.assertEqual(stories.changes(groups, {2: 1, 3: 1}), [])
        self.assertEqual(stories.changes([[TURKEY_X], [TURKEY_SPA], [OTHER]], {2: 1}),
                         [{"main": 1, "others": []}, {"main": 2, "others": []}])


if __name__ == "__main__":
    unittest.main()
