# Sharing scope

This repository is the public copy of WeshFatak's source. It is made by `tools/export_public.py` from the private working copy, which also holds the live project's settings and what the collectors gathered.

## What is not here

- **The live database's address and keys.** The app reads its Supabase project from `app/config/live.json` and the collectors from `collector/.env`; Git ignores both. Built without them, the app opens the demo: two made-up institutions with made-up news, replies, dates and numbers, every link going to example.com. The live project's id is replaced by `YOUR-PROJECT-REF` where the SQL that created Shaqra University points its logo at the live project's storage.
- **Anything collected**: posts, replies, reviews, notes and logs (`collector/data`, `collector/logs`), and the X sign-in profile (`collector/x-profile`). Reply text can identify someone even without a name, so it never leaves the private copy.
- **The live project's history**: the imports with their logs and prompts (`database/news-import`), the first version's SQL (`database/v1-archive`) and the migrations only the live project needed (`migrate-from-v1.sql`, `migrate-to-ministry.sql`).
- **Signing keys, APKs, build output** and files Flutter writes on each computer.

Before copying, the script checks every published text file for the live project's address and keys (read from the private files, so they are never written into the script), key-shaped strings (Supabase, Google, Anthropic, GitHub, AWS, JWTs, private keys), the computer's user folder, and email addresses other than an institution's public contact or a made-up example. If it finds one, it copies nothing.

The commits use a generic author. The GitHub owner's username stays visible.

## Making the next public copy

```powershell
git clone https://github.com/mohammedzayd19992-hash/weshfatak-lab.git ..\weshfatak-lab
python tools\export_public.py ..\weshfatak-lab
cd ..\weshfatak-lab
git status            # review what changed
git add -A
git commit -m "WeshFatak x.y.z"
git push
```

`main` is always the newest version; each version is tagged (`v1.7.0`), and `lab-2026-10-30` marks the first lab copy.

## Checks for 1.7.0 (7 November 2026)

- Flutter analyze: no issues. Flutter tests: 36 passed, among them the whole demo app at double text size in English and Arabic against Flutter's guidelines for touch targets, labels and text contrast.
- Collector tests: 75 passed, without network.
- The live database, from outside with the public key: every table refuses insert, update and delete; the write functions refuse to run; the old profiles are no longer readable. Inside, through the Codex app's Supabase connector: row level security on every public table, no write rights for the public or signed-in roles on any table or view, only three read-only functions open to the public key, no storage upload rules. Supabase's security advisor still warns that leaked-password protection is off, which matters only while sign-ups stay on.
- The export scan: no private value, key, user folder or private email in the published files.

Source checks cannot make every future edit safe. Keep real credentials, personal accounts, exports and screenshots out of this repository.
