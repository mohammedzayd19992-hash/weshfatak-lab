# Collectors

These scripts fill the database the app reads. Which channels exist for each institution, and how they were found, is in [../PROTOCOL.md](../PROTOCOL.md); each channel is a row of the `sources` table, and the scripts read that table to know what to collect.

| Script | Collects | Needs |
|---|---|---|
| `rss.py` | new posts from every RSS source (Shaqra University's hidden feed) | nothing else |
| `collect.py` | an X account's posts and the public replies under them | a signed-in Chrome (below) |
| `reviews.py` | the latest written reviews of every official app on the App Store | nothing else |
| `stats.py` | numbers: Shaqra University's open data API, App Store ratings, and `stats/*.json` written by hand | nothing else |
| `press.py` | what SPA and the Saudi papers report about each institution, and the Ministry's own news pages, through Google News | nothing else |
| `youtube.py` | each collected YouTube channel's latest videos, and their public comments | `YOUTUBE_API_KEY` for comments only |
| `stories.py` | joins one event's copies from X, the website, YouTube and the press into one story | nothing else |
| `notes.py` | Codex reads new replies under each post: a face for every reply and the summary of them | the Codex app, signed in |
| `info.py` | the Info page: is study suspended or online, the coming dates, where to ask, in the order people ask about them | nothing else |
| `autopilot.py` | all of the above, in order, every 2.5 hours, by itself | `SUPABASE_SECRET_KEY` |

For replies and reviews they keep only the text, the time and the likes or stars, never who wrote them.

## Set up once

```powershell
cd collector
python -m pip install -r requirements.txt
copy .env.example .env      # then fill in the Supabase project's URL, publishable key and secret key
python collect.py login     # only for X: sign in in the Chrome window that opens, then close it
```

All three are in the Supabase dashboard under Project Settings → API Keys; the URL and publishable key are the same ones the app is built with (`app/config/live.json`). They live only in `.env`, which Git ignores, so the source names no project. Without the secret key every script still runs and saves its file in `data/`, but nothing reaches the app.

### Without the key: through Codex

The Codex app's Supabase connector can also save, and `UPLOAD_VIA=codex` in `.env` (or in the shell) makes every `upload` go through it: `python press.py upload data/press-….json`. Only Codex can use that link, so Codex copies the rows into its query; each row travels with its md5, and the database refuses the whole batch if one character arrived different (a wrongly copied batch is sent again in halves). It is for one-off uploads; the 2.5-hour autopilot needs the secret key. Codex runs with `--approve-for-me`, its automatic review of tool calls, because saving needs an approval nobody is there to give.

Since the rows hold other people's words and Codex may change the database here, they travel in base64: Codex copies letters it cannot read as instructions, and the database decodes them. Codex also runs without its shell, web search, browser or plugins for this. Four story links took 30 seconds this way.

## Keep it up to date by itself

```powershell
python autopilot.py               # a round now, then one every 2.5 hours; leave the window open
python autopilot.py status        # how each step went last time, and when the next round is
python autopilot.py install       # start it hidden every time you sign in to Windows
```

A round runs `rss`, `press`, `youtube`, `x` (once per X account), `reviews`, `stats` (once a day), `stories`, `notes` and `info`, each as its own program, so one that fails does not stop the others. It writes what each printed to `logs/autopilot-<date>.log` and how each went to `data/autopilot-status.json`. When X says "too many requests", X rests for two rounds. If the computer was asleep when a round was due, the round runs on waking.

Settings in `.env`: `AUTOPILOT_EVERY_HOURS` (2.5), `NOTES_LIMIT` (the most posts Codex reads in one round, 30) and `AUTOPILOT_SKIP` (steps to leave out, for example `x,youtube`). `python autopilot.py --once --skip x` runs one round without X; without the secret key it also leaves Codex out, since notes it could not save would be asked for again next round. `python autopilot.py uninstall` stops it starting at sign-in; it keeps running until you sign out or end it in Task Manager.

The X step opens the collector's Chrome window for a few minutes each round. The computer has to be on for the rounds to run.

Use a spare X account. X's rules do not allow automated collection, and X can lock an account that it thinks is a bot. If X asks you to prove you are human, do it yourself in the Chrome window.

## Collect

```powershell
python rss.py
python collect.py run                         # the Ministry of Education, @moe_gov_sa
python collect.py run --account ShaqraUni     # any account listed in the sources table
python reviews.py
python stats.py
python press.py
python youtube.py
python stories.py                             # after the news collectors: one story per event
python notes.py                               # reads what the others brought in
python info.py                                # last: the Info page
```

Each run saves a file in `data/` and sends it to Supabase. Running again updates what changed without making copies. If the secret key is missing, the file is still saved; send it later with `python <script>.py upload data/<file>.json`.

`collect.py` waits a few seconds between posts. If X answers "too many requests", it stops, keeps what it has, and you can run it again later.

## Add numbers, dates and channels by hand

Ministry figures come from reports and statements, not an API. Add them to `stats/moe.json` (or a new file for another institution), one object per number, with its `period`, `source_name` and `source_url`, then run `python stats.py`. A number with the same label replaces the old one.

The academic calendar and the channels that answer questions are in `info/<institution>.json`: under `dates`, each date with `starts_on` (and `ends_on` when it lasts more than a day); under `help`, each channel with its `link` (`https://`, `tel:` or `mailto:`); every line with its `source_name` and `source_url`. Dates that have ended leave the app by themselves. Add the second semester's dates when the institution announces them, then run `python info.py`.

## What the AI does, and what it costs

AI does one job: `notes.py` reads the replies under a post and gives each a face, then writes the "What people said" summary. It asks once per post, only when the post has replies it has not read; posts without replies cost nothing. Everything else, including every number, date and study announcement on the Info page, comes from plain code reading official sources.

`notes.py` runs Codex (`codex exec`) on the ChatGPT plan the Codex app is signed in with, so it needs no API key. Each question runs in an empty folder, read-only, without your Codex settings or saved sessions, and the answer must match the JSON schema in `NOTE_SCHEMA`. The replies come from strangers, so Codex also runs without its shell, apps (the Supabase connector among them), plugins, web search, browser or computer use: a reply that tries to give it orders can only change the words of one summary, and a note that looks like it carries a key or password is not saved. It reads only public replies on X and YouTube; the old in-app comments, which nobody can add since 1.7.0, are no longer read. It uses the model chosen in the Codex app (`CODEX_MODEL` in `.env` picks another) and records it in each note as `codex:<model>`. A post takes about 20 seconds. When the plan's usage limit is reached, the run stops and the rest waits for the next round. `--engine claude` uses the Claude API instead, with `ANTHROPIC_API_KEY`.

The faces are listed in `FACES` in `notes.py` and explained in PROTOCOL.md. `--all` reads everything again, for example after changing the instructions; `--limit N` reads at most N posts, newest first.

## Check it

```powershell
python -m unittest test_collect.py test_notes.py test_sources.py test_stories.py test_info.py test_autopilot.py
```
