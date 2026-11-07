"""Checks the notes writer without calling Claude. Run: python -m unittest test_notes.py"""

import json
import unittest
from types import SimpleNamespace

import notes

CARD = {"news_id": 7, "handle": "@moe_gov_sa", "source_name": "وزارة التعليم",
        "published_at": "2026-10-22T10:09:44+00:00", "body": "فهم السلوك.. بداية الحل.",
        "reply_count": 3, "community_note": None, "emotions": {}}
REPLIES = [
    {"reply_id": 31, "body": "هل يوجد دعم\nمجاني للأسر؟", "like_count": 4},
    {"reply_id": 32, "body": "ما شاء الله، مبادرة رائعة", "like_count": 0},
    {"reply_id": 33, "body": "النقل المدرسي متأخر", "like_count": 1},
]
ANSWER = {
    "emotions": [{"n": 1, "emotion": "asking"}, {"n": 2, "emotion": "happy"}, {"n": 3, "emotion": "angry"},
                 {"n": 3, "emotion": "sad"}, {"n": 9, "emotion": "happy"}],
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


class DecidesWhatNeedsClaude(unittest.TestCase):
    def test_posts_with_unread_or_unlabeled_replies(self):
        read = {**CARD, "community_note": {"replies_read": 4}, "emotions": {"happy": 3}}
        self.assertTrue(notes.needs_note(CARD))
        self.assertTrue(notes.needs_note({**read, "community_note": {"replies_read": 2}}))
        self.assertTrue(notes.needs_note({**read, "emotions": {"happy": 2}}))
        self.assertFalse(notes.needs_note(read))
        self.assertTrue(notes.needs_note(read, rewrite_all=True))

    def test_posts_without_replies_never_call_claude(self):
        quiet = {**CARD, "reply_count": 0}
        self.assertFalse(notes.needs_note(quiet))
        self.assertFalse(notes.needs_note(quiet, rewrite_all=True))

    def test_a_post_with_more_replies_than_are_read_is_not_asked_about_every_run(self):
        busy = {**CARD, "reply_count": 450,
                "community_note": {"replies_read": notes.MOST_REPLIES}, "emotions": {"angry": notes.MOST_REPLIES}}
        self.assertFalse(notes.needs_note(busy))

class AsksClaude(unittest.TestCase):
    def test_replies_are_numbered_on_one_line_each(self):
        question = notes.question_for(CARD, REPLIES)
        self.assertIn("[1] (4 likes) هل يوجد دعم مجاني للأسر؟", question)
        self.assertIn("[2] ما شاء الله، مبادرة رائعة", question)
        self.assertNotIn("<comments>", question)  # the old in-app comments are never read again

    def test_the_request_uses_structured_output_and_fallbacks(self):
        sent = {}
        notes.write_note(fake_client("end_turn", json.dumps(ANSWER), sent), CARD, REPLIES)
        self.assertEqual(sent["model"], "claude-opus-5-5")
        self.assertEqual(sent["fallbacks"], "default")
        self.assertEqual(sent["output_config"]["format"]["schema"], notes.NOTE_SCHEMA)
        self.assertNotIn("temperature", sent)
        self.assertNotIn("categories", json.dumps(sent["output_config"]))


class ReadsTheAnswer(unittest.TestCase):
    def test_the_note_has_a_face_for_each_reply_and_no_tags(self):
        note = notes.write_note(fake_client("end_turn", json.dumps(ANSWER)), CARD, REPLIES)
        self.assertEqual(note, {
            "news_id": 7,
            "summary": "سأل بعض الأولياء عن دعم مجاني.",
            "key_points": ["دعم مجاني للأسر", "تأخر النقل المدرسي", "ثالث"],
            "replies_read": 3,
            "model": "claude-opus-5-5",
            "emotions": [{"reply_id": 31, "emotion": "asking"}, {"reply_id": 32, "emotion": "happy"},
                         {"reply_id": 33, "emotion": "angry"}],
        })

    def test_a_refusal_gives_nothing(self):
        self.assertIsNone(notes.write_note(fake_client("refusal"), CARD, REPLIES))


def fake_codex(code=0, answer=None, stderr=b"", seen=None):
    """A stand-in for subprocess.run that answers like `codex exec`, writing the -o file."""
    def run(command, input, **options):
        if seen is not None:
            seen.update(command=command, prompt=input.decode("utf-8"), options=options)
        if answer is not None:
            out = command[command.index("--output-last-message") + 1]
            with open(out, "w", encoding="utf-8") as file:
                file.write(answer)
        return SimpleNamespace(returncode=code, stdout=b"", stderr=stderr)
    return run


class RefusesSecrets(unittest.TestCase):
    def test_an_answer_that_repeats_a_key_is_not_saved(self):
        # Made up here so the source holds nothing key-shaped (tools/export_public.py checks for that).
        leaks = ["sb_" + "secret_" + "a" * 16, "SUPABASE_SECRET_KEY=abc", "-----BEGIN " + "PRIVATE KEY-----",
                 "eyJ" + "a" * 12 + ".eyJ" + "b" * 12 + ".x"]
        for leak in leaks:
            answer = {**ANSWER, "key_points": ["دعم مجاني للأسر", leak]}
            self.assertIsNone(notes.note_from(answer, CARD, REPLIES, "codex:x"), leak)
        self.assertIsNotNone(notes.note_from(ANSWER, CARD, REPLIES, "codex:x"))


class AsksCodex(unittest.TestCase):
    def test_the_command_is_read_only_and_ignores_the_users_settings(self):
        seen = {}
        codex = notes.Codex("codex.exe", "gpt-6-astra", run=fake_codex(answer=json.dumps(ANSWER), seen=seen))
        note = notes.write_note(codex, CARD, REPLIES)
        command = seen["command"]
        for flag in ("exec", "--ephemeral", "--ignore-user-config", "--skip-git-repo-check", "--output-schema"):
            self.assertIn(flag, command)
        self.assertEqual(command[command.index("--sandbox") + 1], "read-only")
        disabled = {command[i + 1] for i, part in enumerate(command) if part == "--disable"}
        self.assertTrue({"shell_tool", "apps", "plugins", "browser_use", "computer_use"} <= disabled)
        self.assertIn('web_search="disabled"', command)
        self.assertEqual(command[command.index("--model") + 1], "gpt-6-astra")
        self.assertEqual(command[-1], "-")  # the question on stdin
        self.assertIn("[1] (4 likes) هل يوجد دعم مجاني للأسر؟", seen["prompt"])
        self.assertIn(notes.FACES, seen["prompt"])
        self.assertEqual(note["model"], "codex:gpt-6-astra")
        self.assertEqual(note["summary"], "سأل بعض الأولياء عن دعم مجاني.")
        self.assertEqual(len(note["emotions"]), 3)

    def test_without_a_model_codex_picks_its_own(self):
        seen = {}
        notes.Codex("codex.exe", run=fake_codex(answer=json.dumps(ANSWER), seen=seen)).ask("s", "q", {})
        self.assertNotIn("--model", seen["command"])

    def test_an_answer_that_is_not_json_gives_nothing(self):
        codex = notes.Codex("codex.exe", run=fake_codex(answer="Sorry, I can't."))
        self.assertIsNone(notes.write_note(codex, CARD, REPLIES))

    def test_codex_failing_stops_the_run(self):
        codex = notes.Codex("codex.exe", run=fake_codex(code=1, stderr=b"You've hit your usage limit.\n"))
        with self.assertRaises(notes.CodexError) as raised:
            notes.write_note(codex, CARD, REPLIES)
        self.assertIn("usage limit", str(raised.exception))
        done = notes.each([1, 2], lambda item: notes.write_note(codex, CARD, REPLIES))
        self.assertEqual(done, [])

    def test_the_model_chosen_in_the_codex_app(self):
        self.assertEqual(notes.codex_model({"CODEX_MODEL": "gpt-x"}), "gpt-x")
        self.assertIsNone(notes.codex_model({"CODEX_HOME": "Z:/no/such/folder"}))
        self.assertEqual(notes.find_codex({"CODEX_PATH": "C:/codex.exe"}), "C:/codex.exe")


class SendsTheNotes(unittest.TestCase):
    def test_a_saved_file_goes_to_save_community_note(self):
        sent = []
        original = notes.collect.upload
        notes.collect.upload = lambda path, function, argument, script: sent.append((path, function, argument))
        try:
            notes.upload("notes-1.json")
        finally:
            notes.collect.upload = original
        self.assertEqual(sent, [("notes-1.json", "save_community_note", "p_note")])


if __name__ == "__main__":
    unittest.main()
