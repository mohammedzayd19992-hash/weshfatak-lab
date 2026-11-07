"""Checks the autopilot's decisions without starting any collector. Run: python -m unittest test_autopilot.py"""

import unittest
from datetime import datetime

import autopilot

NOW = datetime(2026, 11, 4, 12, 0)


class DecidesWhatToRun(unittest.TestCase):
    def test_a_full_round_in_order_with_x_once_per_account(self):
        plan = autopilot.commands({}, set(), ["moe_gov_sa", "ShaqraUni"], 30, NOW)
        self.assertEqual([name for name, *_ in plan],
                         ["rss", "press", "youtube", "x moe_gov_sa", "x ShaqraUni", "reviews", "stats",
                          "stories", "notes", "info"])
        steps = {name: args for name, args, _ in plan}
        self.assertEqual(steps["x ShaqraUni"][-2:], ["--account", "ShaqraUni"])
        self.assertEqual(steps["notes"], ["notes.py", "--limit", "30"])

    def test_the_numbers_once_a_day(self):
        state = {"last_success": {"stats": "2026-11-04T02:00:00"}}
        plan = dict((name, args) for name, args, _ in autopilot.commands(state, set(), [], 30, NOW))
        self.assertIsNone(plan["stats"])
        later = datetime(2026, 11, 5, 1, 55)
        plan = dict((name, args) for name, args, _ in autopilot.commands(state, set(), [], 30, later))
        self.assertEqual(plan["stats"], ["stats.py"])

    def test_skipped_steps_and_x_resting(self):
        plan = {name: (args, why) for name, args, why in
                autopilot.commands({"x_rest": 2}, {"youtube"}, ["moe_gov_sa"], 30, NOW)}
        self.assertEqual(plan["youtube"], (None, "skipped"))
        self.assertIsNone(plan["x"][0])
        self.assertIn("resting", plan["x"][1])

    def test_info_leaves_the_study_status_when_press_failed(self):
        self.assertEqual(autopilot.info_args(["info.py"], {"press": "failed"}), ["info.py", "--no-status"])
        self.assertEqual(autopilot.info_args(["info.py"], {"press": "sent"}), ["info.py"])


class ReadsHowAStepWent(unittest.TestCase):
    def test_outcomes(self):
        self.assertEqual(autopilot.outcome(0, "Sent 12 rows to Supabase."), "sent")
        self.assertEqual(autopilot.outcome(0, "Not sent to Supabase: put SUPABASE_SECRET_KEY ..."), "saved")
        self.assertEqual(autopilot.outcome(0, "142 posts make 112 stories.\nNo changes."), "nothing new")
        self.assertEqual(autopilot.outcome(0, "X says too many requests. Stopping here"), "limited")
        self.assertEqual(autopilot.outcome(1, "Not signed in to X."), "failed")

    def test_the_worst_of_two_accounts_is_reported(self):
        self.assertEqual(autopilot.worst("sent", "limited"), "limited")
        self.assertEqual(autopilot.worst("failed", "sent"), "failed")
        self.assertEqual(autopilot.worst("sent", "sent"), "sent")

    def test_last_words(self):
        self.assertEqual(autopilot.last_words("one\n\n  two  \n"), "two")
        self.assertEqual(autopilot.last_words(""), "")

    def test_a_dead_process_is_not_running(self):
        self.assertFalse(autopilot.alive(2 ** 22 + 7))  # no Windows process has an id this odd


if __name__ == "__main__":
    unittest.main()
