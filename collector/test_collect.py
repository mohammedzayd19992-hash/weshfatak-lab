"""Checks how the collector reads X's JSON. Run: python -m unittest test_collect.py"""

import unittest

import collect


def tweet(rest_id, screen_name, text, conversation=None, **legacy):
    return {
        "__typename": "Tweet",
        "rest_id": rest_id,
        "core": {"user_results": {"result": {
            "__typename": "User", "rest_id": "u-" + screen_name,
            "core": {"screen_name": screen_name},
            "avatar": {"image_url": f"https://pbs.twimg.com/profile_images/1/{screen_name}_normal.jpg"},
            "legacy": {"created_at": "Mon Jan 01 00:00:00 +0000 2018"},
        }}},
        "legacy": {
            "created_at": "Thu Oct 22 07:30:00 +0000 2026",
            "full_text": text,
            "display_text_range": [0, len(text)],
            "conversation_id_str": conversation or rest_id,
            "favorite_count": 0,
            **legacy,
        },
    }


# One answer shaped like X's: tweets buried in timeline instructions.
ANSWER = {"data": {"user": {"result": {"timeline": {"timeline": {"instructions": [{"entries": [
    # A ministry post with a photo and a t.co link to the photo at the end
    {"content": {"itemContent": {"tweet_results": {"result": tweet(
        "100", "moe_gov_sa", "بدء العام الدراسي الأحد &amp; التسجيل https://t.co/photo",
        display_text_range=[0, 37],
        extended_entities={"media": [
            {"type": "photo", "media_url_https": "https://pbs.twimg.com/media/a.jpg",
             "original_info": {"width": 1200, "height": 675}, "ext_alt_text": "جدول"},
            {"type": "video", "media_url_https": "https://pbs.twimg.com/media/v.jpg",
             "original_info": {"width": 1280, "height": 720}},
        ]},
    )}}}},
    # A long post (X keeps the full text in note_tweet), wrapped in TweetWithVisibilityResults
    {"content": {"itemContent": {"tweet_results": {"result": {
        "__typename": "TweetWithVisibilityResults",
        "tweet": {**tweet("101", "moe_gov_sa", "short version…"),
                  "note_tweet": {"note_tweet_results": {"result": {
                      "text": "The full long announcement https://t.co/x",
                      "entity_set": {"urls": [{"url": "https://t.co/x", "expanded_url": "https://moe.gov.sa/a"}]},
                  }}}},
    }}}}},
    # A repost and a reply to someone else: not ministry posts
    {"content": {"itemContent": {"tweet_results": {"result": tweet(
        "102", "moe_gov_sa", "RT @someone: hello", retweeted_status_result={"result": {}})}}}},
    {"content": {"itemContent": {"tweet_results": {"result": tweet(
        "103", "moe_gov_sa", "@student thanks", in_reply_to_status_id_str="55")}}}},
    # Someone else's post
    {"content": {"itemContent": {"tweet_results": {"result": tweet("104", "other", "not ours")}}}},
]}]}}}}}}

REPLIES = {"data": {"threaded_conversation_with_injections_v2": {"instructions": [{"entries": [
    {"content": {"itemContent": {"tweet_results": {"result": tweet(
        "100", "moe_gov_sa", "the post itself")}}}},
    {"content": {"items": [
        {"item": {"itemContent": {"tweet_results": {"result": tweet(
            "200", "parent1", "@moe_gov_sa متى يبدأ التسجيل؟ https://t.co/l", conversation="100",
            display_text_range=[12, 44], favorite_count=12,
            entities={"urls": [{"url": "https://t.co/l", "expanded_url": "https://example.com"}]})}}}},
        {"item": {"itemContent": {"tweet_results": {"result": tweet(
            "201", "moe_gov_sa", "@parent1 من الأحد", conversation="100")}}}},
        {"item": {"itemContent": {"tweet_results": {"result": tweet(
            "202", "parent2", "@moe_gov_sa ", conversation="100", display_text_range=[12, 12])}}}},
    ]}},
    {"content": {"itemContent": {"tweet_results": {"result": tweet(
        "300", "someone", "a reply in another conversation", conversation="999")}}}},
]}]}}}


class ReadsMinistryPosts(unittest.TestCase):
    def setUp(self):
        self.posts = collect.ministry_posts([ANSWER])

    def test_keeps_only_the_ministrys_own_posts(self):
        self.assertEqual(sorted(self.posts), ["100", "101"])

    def test_post_text_drops_the_photo_link_and_html_escapes(self):
        self.assertEqual(self.posts["100"]["text"], "بدء العام الدراسي الأحد & التسجيل")

    def test_long_posts_are_complete_with_links_expanded(self):
        self.assertEqual(self.posts["101"]["text"], "The full long announcement https://moe.gov.sa/a")

    def test_photos_are_kept_with_their_size_and_videos_are_not(self):
        self.assertEqual(self.posts["100"]["images"], [
            {"url": "https://pbs.twimg.com/media/a.jpg", "alt": "جدول", "width": 1200, "height": 675}])

    def test_post_is_ready_for_the_database(self):
        post = self.posts["100"]
        self.assertEqual(post["handle"], "@moe_gov_sa")
        self.assertEqual(post["url"], "https://x.com/moe_gov_sa/status/100")
        self.assertEqual(post["posted_at"], "2026-10-22T07:30:00+00:00")
        self.assertEqual(post["avatar_url"], "https://pbs.twimg.com/profile_images/1/moe_gov_sa_400x400.jpg")


class ReadsReplies(unittest.TestCase):
    def setUp(self):
        self.replies = collect.replies_to("100", [REPLIES])

    def test_keeps_other_peoples_replies_to_this_post_only(self):
        self.assertEqual([r["id"] for r in self.replies], ["200"])

    def test_reply_has_text_time_and_likes_but_no_author(self):
        self.assertEqual(self.replies[0], {"id": "200", "text": "متى يبدأ التسجيل؟ https://example.com",
                                           "posted_at": "2026-10-22T07:30:00+00:00", "likes": 12})


if __name__ == "__main__":
    unittest.main()
