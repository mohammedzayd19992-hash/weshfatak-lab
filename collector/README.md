# Optional development collector

These scripts are included for source review and are not needed for the offline lab preview. No saved login session, collected posts/replies, API credentials or browser profile is included. Live backend defaults have been removed.

Use synthetic fixtures in the tests for the lab. Install `requirements.txt` and run `python -m unittest test_collect.py test_notes.py` from this folder. Do not run live collection for the submission: reply text can itself contain personal information even when author fields are omitted.

Any separate development configuration must use a disposable backend. Copy `.env.example` to `.env` locally and never commit it. The note script also needs its `PUBLISHABLE_KEY` configured for that disposable backend before connected use. Browser profiles, raw data and logs are excluded by `.gitignore`.
