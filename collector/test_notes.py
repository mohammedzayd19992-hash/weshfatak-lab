"""Checks the notes writer without calling Claude. Run: python -m unittest test_notes.py"""

import json
import unittest
from types import SimpleNamespace

import notes

CARD = {"news_id": 7, "handle": "@moe_gov_sa", "published_at": "2026-10-22T10:09:44+00:00",
        "body": "فهم السلوك.. بداية الحل.", "category": [], "reply_count": 3, "comment_count": 1,
        "community_note": None}
REPLIES = [
    {"body": "هل يوجد دعم\nمجاني للأسر؟", "like_count": 4},
    {"body": "ما شاء الله، مبادرة رائعة", "like_count": 0},
    {"body": "النقل المدرسي متأخر", "like_count": 1},
]
COMMENTS = [{"body": "مفيد جدا"}]
ANSWER = {
    "categories": ["Activities"], "audiences": ["Students"],
    "summary": "  سأل بعض الأولياء عن دعم مجاني.  ",
    "key_points": ["دعم مجاني للأسر", " ", "تأخر النقل المدرسي", "ثالث", "رابع"],
}


def fake_client(stop_reason, text="", sent=None):
    def create(**request):
        if sent is not None:
            sent.update(request)
        return SimpleNamespace(stop_reason=stop_reason, model=request["model"],
                               content=[SimpleNamespace(type="text", text=text)])
    return SimpleNamespace(beta=SimpleNamespace(messages=SimpleNamespace(create=create)))


class DecidesWhichPostsNeedANote(unittest.TestCase):
    def test_untagged_posts_and_posts_with_new_replies(self):
        tagged = {**CARD, "category": ["Activities"]}
        self.assertTrue(notes.needs_note(CARD))
        self.assertTrue(notes.needs_note({**tagged, "community_note": {"replies_read": 2}}))
        self.assertFalse(notes.needs_note({**tagged, "community_note": {"replies_read": 4}}))
        self.assertFalse(notes.needs_note({**tagged, "reply_count": 0, "comment_count": 0}))
        self.assertTrue(notes.needs_note({**tagged, "community_note": {"replies_read": 4}}, rewrite_all=True))


class AsksClaude(unittest.TestCase):
    def test_question_lists_every_reply_and_comment_on_one_line(self):
        question = notes.question_for(CARD, REPLIES, COMMENTS)
        self.assertIn("- (4 likes) هل يوجد دعم مجاني للأسر؟", question)
        self.assertIn("- ما شاء الله، مبادرة رائعة", question)
        self.assertIn("<comments>\n- مفيد جدا\n</comments>", question)

    def test_a_post_without_replies_is_only_tagged(self):
        self.assertIn("Nobody has replied yet.", notes.question_for(CARD, [], []))

    def test_the_request_uses_structured_output_and_fallbacks(self):
        sent = {}
        notes.write_note(fake_client("end_turn", json.dumps(ANSWER), sent), CARD, REPLIES, COMMENTS)
        self.assertEqual(sent["model"], "claude-opus-5-5")
        self.assertEqual(sent["fallbacks"], "default")
        self.assertEqual(sent["output_config"]["format"]["schema"], notes.SCHEMA)
        self.assertNotIn("temperature", sent)


class ReadsTheAnswer(unittest.TestCase):
    def test_the_note_is_trimmed_and_counts_every_opinion(self):
        note = notes.write_note(fake_client("end_turn", json.dumps(ANSWER)), CARD, REPLIES, COMMENTS)
        self.assertEqual(note, {
            "news_id": 7,
            "summary": "سأل بعض الأولياء عن دعم مجاني.",
            "key_points": ["دعم مجاني للأسر", "تأخر النقل المدرسي", "ثالث"],
            "replies_read": 4,
            "model": "claude-opus-5-5",
            "categories": ["Activities"],
            "audiences": ["Students"],
        })

    def test_without_replies_only_the_tags_are_kept(self):
        note = notes.note_from(ANSWER, CARD, 0, "claude-opus-5-5")
        self.assertEqual((note["summary"], note["categories"]), ("", ["Activities"]))

    def test_a_refusal_gives_no_note(self):
        self.assertIsNone(notes.write_note(fake_client("refusal"), CARD, REPLIES, COMMENTS))


if __name__ == "__main__":
    unittest.main()
