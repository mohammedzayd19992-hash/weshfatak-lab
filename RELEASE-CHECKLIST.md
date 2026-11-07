# WeshFatak · وش فاتك — session checklist

## 1.8.0 — a prototype, with the automation on hold (7 November 2026)

Asked for: hold the automation, but make the app ready as a prototype.

- [x] **The data's date where it matters.** With the collectors off, the data stops at 4 November. The home screen now reads "Prototype · data up to Wed Nov 4" (or "updated 3 h ago" while the collectors run), from the newest post or Info check, so it changes by itself when collection starts again. Tapping it opens the About page.
- [x] **A study card that cannot pass for today's.** The Ministry's card still listed Riyadh's and Taif's move online "until Thursday" (5 November). When nobody has checked for a day, it now begins "Not checked since Wed Nov 4, 3 days ago, so this may be out of date", and "no announcement" says which 7 days it means.
- [x] **About page:** what WeshFatak is; that it is a student prototype, not an official service; how old the data is; where everything comes from; what AI does and does not do; what stays on the phone; the version, feedback and the source code.
- [x] **Report a mistake** under "What people said" on every story page, and "Send feedback" on the About page. Both open the public repository's issue form, with the story filled in, or the page a build gives as `FEEDBACK_URL`.
- [x] **Alerts while paused:** turning on the bell says no news will come until collection starts again.
- [x] **A display fix:** in English, an Arabic outlet's name before "3 days ago" under a study announcement showed as "3 · المرصد days ago".
- [x] **The automation on hold:** README, collector/README and DEMO.md say so, and `python autopilot.py --once` brings the data up to date once. Nothing was installed or scheduled.
- [x] **DEMO.md:** the day before (Supabase's free plan pauses after a week without visits), a three-minute walkthrough, questions for testers, showing it on a laptop.
- [x] Version 1.8.0+2010 (phone code 4010 for the ARM64 APK), signed with the same certificate, so it installs over 1.7.0.
- [ ] **You, in the Supabase dashboard:** turn off sign-ups (Authentication → Sign In / Providers). On 7 November they were still on.
- [ ] Install `apk/WeshFatak-1.8.0-arm64.apk` and go through DEMO.md's three minutes once on the phone, a minute of it with TalkBack and the largest text.

Checks: Flutter analyze clean; 45 Flutter tests pass, among them the whole demo app at double text size in English and Arabic, now through the About page and "Report a mistake", against Flutter's touch target, label and contrast guidelines; 75 collector tests pass; the web build checked in the browser at phone size against the live database (the prototype line, the About page, the study card's note).

### Is it a ready prototype?

**Yes, to show and to test with people.** It runs on real data from every collected channel, says honestly how old that data is, explains itself on the About page, takes feedback, works offline, in Arabic, with a screen reader and at large text, and the public source runs on its own as a demo.

**Still missing for the public at large:**

1. **The data has to keep flowing.** On hold by choice. Ending the hold needs the secret key and `python autopilot.py install` on a computer that stays on (X needs its signed-in Chrome), or the collectors that need no browser moved to a schedule in the cloud.
2. **Turn off sign-ups** (above).
3. **Google Play:** a protected upload key instead of the debug certificate, an Android App Bundle, a privacy policy page (the About page's privacy part is a start), the Data safety form, a content rating, store screenshots and text, a support contact, and for a personal developer account made after 13 November 2023 a closed test with 12 testers for 14 days.
4. **Coverage:** the regional education departments, Shaqra's second-semester dates when announced, more universities.
5. **X:** its rules forbid automated collection, and it can lock the collecting account. Replies are the heart of "What people said".
6. **Feedback without an account:** "Report a mistake" opens GitHub's issue form, which needs a GitHub account; a form of the project's own (`FEEDBACK_URL`) would reach more people.
7. **Not checked on a real phone yet:** TalkBack and large text, notifications arriving, offline use.
8. **No alert when a collection round fails.**
9. **iPhone:** not built (it needs a Mac and an Apple developer account).

## 1.7.0 — public on GitHub, accessible, works offline, accounts closed (7 November 2026)

Asked for: update the public GitHub with 1.6.0 and hide what should not be shared; accessibility for people who need it; security where needed; connectivity; and what is still missing to call it ready.

- [x] **Public copy.** The public repository (`weshfatak-lab`, last updated 30 October) gets 1.7.0 through `tools/export_public.py`, which copies only what may be public and refuses if a file holds the live project's address or keys, a key-shaped string, the computer's user folder or a private email. See SHARING.md.
- [x] **No project in the source.** The app reads its Supabase URL and publishable key from `app/config/live.json` at build time (`--dart-define-from-file`), and the collectors from `collector/.env`; Git ignores both. Without them the app opens a **demo** with two made-up institutions, so the public source runs straight after cloning, and the tests run the whole app.
- [x] **Accessibility.** Screen readers read each card as one item, sections as headings, faces by name and share instead of emoji, stars, likes and counts as words; the demo and offline lines are announced. Everything follows the phone's text size, and rows that would not fit at 200% now stack (the faces, the "What people said" header, number bars, star counts, countdowns, source status, the reply footer: the new test found each of them overflowing). Every target is at least 48 by 48 (the face filter chip was 40), a refresh button sits beside pull-to-refresh, and animations stop when the phone asks for less motion.
- [x] **Offline.** Each page loaded is kept on the phone; without a connection, or after 15 seconds without an answer, the page shows what it showed last time with a line saying since when. The 20 most recently opened stories are kept with their replies.
- [x] **Security, database.** `migrate-close-accounts.sql`, applied to the live project through Codex: the old accounts' tables no longer let anyone add comments or profiles, and the 3 profiles' names are no longer public. Sign-ups were still open, and `notes.py` read those comments into the AI, so a stranger could have signed up and steered the summaries. Audit afterwards: row level security on every table, no write rights for the public or signed-in roles, only three read-only functions open to the public key, no storage upload rules.
- [x] **Security, app.** The leftover sign-in link (`uninews://login-callback`) is gone, so no link opens the app; Supabase no longer looks for sign-in links or keeps a session; the app opens only web, phone and email links; plain HTTP is refused.
- [x] **Security, AI.** `notes.py` runs Codex without its shell, apps (the Supabase connector), plugins, web search, browser or computer use, so a reply that tries to give orders can only change one summary's words; a note that looks like it carries a key is not saved; the old in-app comments are no longer read. Uploads through Codex send rows in base64 so their text cannot act as instructions. Both checked live.
- [x] Version 1.7.0+2009 (phone code 4009 for the ARM64 APK), signed with the same certificate, so it installs over 1.6.0.
- [ ] **You, in the Supabase dashboard:** Authentication → Sign In / Providers → turn off "Allow new users to sign up" (and the email provider). The database now ignores members, but no one should be able to create one.
- [ ] **You:** `SUPABASE_SECRET_KEY` in `collector/.env`, then `python autopilot.py install`, so the data keeps updating.
- [ ] Install `apk/WeshFatak-1.7.0-arm64.apk` and try it with TalkBack and the phone's largest text, and once in airplane mode.

Checks: Flutter analyze clean; 36 Flutter tests (the whole app at double text size in English and Arabic against Flutter's touch target, label and contrast guidelines) and 75 collector tests pass; the live database probed from outside with the public key and audited inside through Codex; a live upload through Codex in base64 (30 seconds); the export scan clean.

### Is it ready?

**Ready** as a lab project and for phone testing: the idea works end to end, from the collectors and the 2.5-hour autopilot to the app, and the public source runs on its own.

**Not yet ready for the public at large:**

1. **The data has to keep flowing.** Nothing updates until the secret key is in `.env` and the autopilot runs, and it runs on one Windows computer that must stay on (X needs that computer's signed-in Chrome). Next step: run the collectors that need no browser (press, RSS, YouTube, stories, info) on a schedule in the cloud, and keep only X on the computer.
2. **Turn off sign-ups** (above).
3. **Google Play:** a protected upload key instead of the debug certificate, an Android App Bundle, a privacy policy page linked in the app, the Data safety form (the app collects nothing personal; it keeps followed institutions and copies of pages on the phone), a content rating, store screenshots and text, a support contact, and, for a personal developer account made after 13 November 2023, a closed test with 12 testers for 14 days.
4. **Coverage:** the regional education departments' own accounts (Jeddah's 1–5 November move online reached no collected outlet), Shaqra's second-semester dates when announced, and more universities.
5. **X:** its rules forbid automated collection, and it can lock the collecting account. Replies are the heart of "What people said", so this is the biggest risk to the idea; the official X API costs money.
6. **AI mistakes:** a summary can misread the replies. Add a "report a mistake" link once the project has its own contact address (not a personal one).
7. **Not checked on a real phone yet:** TalkBack and large text, notifications arriving, offline use.
8. **No alert when a round fails:** `python autopilot.py status` and the logs show it, but nobody is told.
9. **iPhone:** not built (it needs a Mac and an Apple developer account).

## 1.6.0 — the Info page answers what people ask, and it all updates itself (4 November 2026)

Feedback on 1.5.0: the Info page is good, but is its order random? It should give people what they need and cannot get from X. Also: a Python program that keeps all of it up to date every 2.5 hours with Codex, and not so much AI that it hurts the idea.

- [x] Counted what the 257 different replies under the Ministry's and Shaqra's posts ask: study suspended or online 40, exams and dates 24, how to reach someone 22, the apps 15, the statistics 0 (table in PROTOCOL.md). The old order was the numbers that had a source, not what people asked.
- [x] The Info page now goes: **study** (the newest official word from the last week on study being suspended, online or back in person, or a plain "no announcement", with when it was checked), **coming up** (the academic calendar counting down: the Ministry's 1448 calendar and Shaqra's first semester), **where to ask** (Tawasul and 19996 for the Ministry; Shaqra's contact form, phone and email, and Tawasul when it does not answer), **its apps**, then **numbers**. `info.py` re-orders the first four by what the last 30 days of replies asked; numbers always come last.
- [x] `press.py` also searches each outlet for the Ministry's regional decisions on study, which rarely name the Ministry, and four Saudi e-papers that carried this week's (Sada, Saraha, Shahd Now, Al-Marsd) count for those only. A live run found Riyadh's and Taif's move online (1 to 5 November), Al-Jouf's, Hail's and Taif University's, and left out France, Yemen, technical training and tag pages.
- [x] `autopilot.py` runs every collector in order every 2.5 hours (stats once a day), each as its own program; logs, a status command, X resting after "too many requests", catching up after sleep, and `install` to start hidden at Windows sign-in. It will not loop without the secret key.
- [x] `notes.py` asks Codex on the ChatGPT plan instead of the paid Claude API: read-only, in an empty folder, JSON schema enforced; tested live on one post (18 seconds, every reply given a face). It is the only AI: numbers, dates and study announcements never come from it. The app now says the summaries are by AI instead of naming Claude.
- [x] `database/migrate-to-info.sql` adds `info_sections`, `info_items` and `save_info_section` (only additions; 1.5.0 phones keep working), with `checks-info.sql`.
- [x] `migrate-to-info.sql` applied to the live project through the Codex app's Supabase connector (migration `info_people_ask`), wrapped so it ran only if its md5 matched the file. Checked from outside: the app's key reads `info_sections` and `info_items` and is refused when it tries to save or insert.
- [x] First fill, through Codex with every row md5-checked: this week's 18 press reports (18 of 18 in the database exactly as collected, the Ministry now 73 stories), 4 story groups, and the Info page (10 sections, 28 items, no difference from `info.py`'s file). The live web app shows both Info pages: the Ministry's study card has Riyadh's and Taif's move online, checked 20:32.
- [ ] Run `checks-info.sql` in the SQL Editor (the outside checks above cover its security part).
- [ ] Paste `SUPABASE_SECRET_KEY` into `collector/.env`, then `python autopilot.py` (or `install`). Through Codex, one round would take about an hour, so the loop needs the key.
- [ ] Install `apk/WeshFatak-1.6.0-arm64.apk` (version code 4008, over 1.5.0) on a phone and open both Info pages.
- [ ] Follow the regional education departments' own accounts: Jeddah's move online (1 to 5 November) reached none of the collected outlets.

Checks: Flutter analyze clean; 28 Flutter tests and 69 collector tests pass; press.py and info.py run live against the database (saving files, since there is no secret key); the Info pages checked in the browser at phone size in Arabic, the database's rows plus the sections info.py worked out, through a local preview server.

## 1.5.0 — every source, and what people said under every story (2 November 2026)

Feedback on 1.4.1: most posts had no "What people said", and the news was still mostly X.

- [x] New X posts with their replies: the Ministry's last 20 (139 replies) and Shaqra's last 20 (138 replies). Before, the Ministry had 5 posts and Shaqra's posts had no replies.
- [x] Every one of these 40 posts has its faces and its "What people said" summary, written by Claude in this session with the same instructions as `notes.py`.
- [x] The press: `press.py` reads Google News outlet by outlet: 42 Ministry reports and 9 Shaqra reports in 45 days from SPA, Sabq, Al-Madina, Ajel, Okaz, Al-Riyadh, Al-Jazirah and Argaam. They include useful news that was missing, such as 10 days of remote study and the minister on licensing new universities, plus critical reports (the Shura Council asking Shaqra for a ranking plan).
- [x] The Ministry's own website news (11 pages), which its site gives out only through an internal API, arrives through Google News's list of its news folder.
- [x] YouTube: `youtube.py` reads the Ministry's 15 latest videos, among them "the exam timetable in Noor". Comments come with a YouTube Data API key.
- [x] One story per event: `stories.py` joins the X post, website page, video and press reports of the same event. 142 posts make 112 stories. The main post is the one with replies, so its "What people said" covers the story; the others show as "Also reported by" links.
- [x] Press reports show the outlet's name and a newspaper icon instead of the "official source" mark. The website and YouTube posts show the institution's logo.
- [x] The post page says when a source cannot be replied to, and calls YouTube comments "Comments on YouTube".

Checks: Flutter analyze clean; 18 Flutter tests and 36 collector tests pass; web build checked in the browser at phone size in Arabic against the live database.

## 1.4.1 — the mood belongs to the news (2 November 2026)

Feedback on 1.4.0: news is the core of the app, and the mood should be part of each news post, not a tab of its own.

- [x] An institution's page opens on its news. The Mood tab is gone; the tabs are News, Info and Sources.
- [x] Each post's "What people said" box holds its faces: in the news list the strip and the two most common faces above the summary; on the post page every face with its share, and tapping one shows only its replies.
- [x] The home screen shows each institution's latest news, then the faces of the replies under its news. They no longer include app reviews, which had made the ministry look mostly angry (38 of 68); the replies to its news are 10 happy, 7 asking, 3 angry.
- [x] App reviews moved to the Info page, newest first with their stars and no faces.
- [x] `notes.py` reads replies only: no more calls for review faces or institution pulses. The database keeps those tables, unused, so older builds keep working.

Checks: Flutter analyze clean; 16 Flutter tests and 25 collector tests pass.

## 1.4.0 — institution pages and mood charts (1 November 2026)

Requested by the supervising doctor: less like X, more useful and unique.

- [x] Remove accounts, sign-in, profiles and in-app comments from the app. The database tables stay, unused, so the 1.3 app keeps working until phones update.
- [x] Remove audience and category tags and filters. Claude no longer tags posts, so posts without replies cost no AI call.
- [x] Bring back a page for every institution: Ministry of Education and Shaqra University, with Shaqra's 16 archived posts restored and 6 new ones from its RSS feed.
- [x] Mood charts with seven faces, per post and per institution, from replies on X and App Store reviews; tap a face to filter. Colors checked for colorblind separation and contrast on the dark theme.
- [x] An Info tab of statistics with period and source: 15 for Shaqra (open data API, App Store), 12 for the ministry (press statements, App Store).
- [x] A Sources tab and [PROTOCOL.md](PROTOCOL.md): every channel found, including hidden ones (Shaqra's unlinked RSS feed and open data API, the ministry's four App Store apps).
- [x] Alerts now follow institutions instead of filters.
- [x] Arabic phones get the whole app in Arabic, right to left.

Checks: Flutter analyze clean; 15 Flutter tests and 29 collector tests pass; web build checked in the browser at phone size in English and Arabic against the live database.

Still to do:

- [ ] Put `SUPABASE_SECRET_KEY` and `ANTHROPIC_API_KEY` in `collector/.env`, then run `python reviews.py upload data/reviews-20261101-1908.json` (all 402 reviews for the Info page; 60 are loaded so far). Since 1.4.1, `notes.py` no longer reads reviews. Without the secret key every collector saves its file but cannot send it; on 2 November the files were loaded by hand through the Supabase connector.
- [x] Run `python collect.py run --account ShaqraUni` so Shaqra's posts get replies and faces from X (done 2 November, 20 posts, 138 replies).
- [ ] Optional: a YouTube Data API key (`YOUTUBE_API_KEY`) so the Ministry's videos get their comments and faces.
- [ ] Run the collectors on a schedule (daily: `rss.py`, `press.py`, `youtube.py`, `stories.py`; weekly: `collect.py run` for each X account; then `notes.py`).
- [ ] Install the 1.4.0 APK on a phone; follow an institution and check a notification arrives and opens the post.
- [ ] Android unit tests: the old filter rule tests were removed with the filters; the worker's new query was checked against Supabase by hand only.

## 1.2.0 — earlier session (19 October 2026)

Continued from Claude's “Claude GitHub connection” session.

## Requested changes

- [x] Remove the profile bio from the phone app. Claude had already removed it from the app and live database.
- [x] Keep eight universities total, including Shaqra, as confirmed by the user. The app and new-database seed use the same list.
- [x] Complete the interrupted news import. The live database now has 123 posts across the eight selected universities, with no duplicate source URLs.
- [x] Include official university website news, alongside the existing Shaqra X posts.
- [x] Keep the full-screen image viewer with image swiping, pinch zoom and double-tap zoom. Confirmed the viewer opens in the browser preview; added browser image fallback.
- [x] Rename the visible app to **وش فاتك** on Arabic phones and **WeshFatak** on English phones. Launcher resources, in-app titles and accessible logo names are updated. Other phone languages fall back to WeshFatak. This change localizes the name; the existing app has not been fully translated.
- [x] Add news notifications for independent saved filters. Use the bell in the feed, then “Save alert for this filter.” Up to ten filters can be saved, paused or removed. Changing the current feed does not replace saved alerts. Reading and alerts work for guests.
- [x] Offer “Important categories only”: Academic, Exams and Administrative news. This uses categories, not a claim that an editor has marked a story urgent. Activities can be included by turning this option off.
- [x] Match university AND selected categories AND audience, including university-wide news with no audience restriction. A student filter excludes staff-only stories.
- [x] Avoid notifying the old archive when alerts are first enabled. Only newly collected posts since that alert was enabled are eligible. Overlapping filters notify each story once.
- [x] Open the matching story when a notification is tapped.
- [x] Build an APK update using the previous package ID and signing certificate, with version 1.2.0 / code 2003, above the previous ARM64 code 2002.

## University coverage

The collected articles are a selection across the requested six-month window, not an exhaustive archive. Counts include the two original Shaqra screenshot posts.

| University | Posts | Publication dates |
| --- | ---: | --- |
| Shaqra | 16 | 28 Apr–15 Oct 2026 |
| King Saud | 14 | 19 Apr–15 Oct 2026 |
| King Abdulaziz | 16 | 22 Apr–18 Oct 2026 |
| Imam Mohammad Ibn Saud Islamic | 16 | 27 Apr–15 Oct 2026 |
| King Fahd University of Petroleum and Minerals | 18 | 26 Apr–15 Oct 2026 |
| Princess Nourah bint Abdulrahman | 15 | 21 Apr–18 Oct 2026 |
| King Abdullah University of Science and Technology | 15 | 26 Apr–14 Oct 2026 |
| Umm Al-Qura | 13 | 23 Apr–15 Oct 2026 |

Imam Abdulrahman Bin Faisal University was omitted to keep eight total. Its research had only two articles with publication/event-date discrepancies. The existing empty database university row was retained; it is absent from app choices and the new-database seed.

## Notification timing and phone check

Android WorkManager checks the public news API periodically, normally every 15 minutes or longer. It works after closing the app, subject to Android battery and network scheduling. Force stop suspends checks until the app is reopened. These are periodic background notifications; immediate server push is not implemented. News must be added to the database for new alerts to exist; ongoing automated news collection is still a separate production task.

- [ ] Install WeshFatak-1.2.0-test.apk over the previous UniNews app on a physical phone.
- [ ] Check launcher and app titles with English and Arabic phone languages.
- [ ] Select Students and the desired university, tap the bell, allow Android notifications, then save the filter.
- [ ] Close the app and verify a newly added matching news story delivers and opens correctly; check a staff-only story does not alert the student subscription.
- [ ] Check pause/remove, overlapping filters, denied permission, reboot, offline recovery and the phone's battery settings.
- [ ] Check image pinch zoom and swiping on the phone.

No Android phone was connected during this session, so end-to-end device delivery has not been verified.

## Validation

- Flutter static analysis: no issues.
- Flutter tests: eight passed, covering existing data/filter/date behavior, localized names, independent saved-alert persistence, disabled states and duplicate-filter prevention.
- Android unit tests: three passed, covering audience restrictions, category intersection and important-only filtering.
- Release APK compiled; Android target API 36. English and Arabic launcher names inspected in the compiled APK.
- Previous and new signing certificate fingerprints match. The build uses the existing Android Debug certificate, so it is a test APK.
- The background worker's exact public REST relationship query was exercised successfully against Supabase using the publishable key.
- Live import totals and absence of duplicate source URLs checked with SQL.
- Browser preview checked for the eight university choices, imported university feed and image viewer.

## Is it ready for Google Play?

**Ready for another phone test; not ready for a production Google Play submission.**

- [ ] Replace debug signing with a protected upload key and build a properly signed Android App Bundle. Google Play does not accept the existing debug-signed APK for publishing. [Android app signing](https://developer.android.com/studio/publish/app-signing)
- [ ] Publish and link a privacy policy in the app and Play Console, and complete accurate Data Safety declarations for account/email, profile name, comments, saved filters and the services actually used. [User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311)
- [ ] Provide an in-app account-deletion route and an external account-deletion request page, including deletion of associated data. The current app has account creation but no deletion route. [Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)
- [ ] Add comment/user reporting, user blocking, terms and an operational moderation process for public comments. These controls are absent in the current app. [User-generated content policy](https://support.google.com/googleplay/android-developer/answer/9876937)
- [ ] Finish real-phone checks, ongoing news collection, store screenshots/descriptions, support contact, content rating and the applicable Play Console declarations.
- [ ] If using a personal developer account created after 13 November 2023, run the required closed test with at least 12 testers continuously opted in for 14 days before applying for production access. This depends on the developer account; it was not inspected. [Google testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465)

The source changes are local. This session did not push a GitHub commit or publish the app.
