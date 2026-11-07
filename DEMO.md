# Showing the prototype

WeshFatak 1.8.0 is a prototype: the whole idea works on real data, but the data is a snapshot. The collectors and the 2.5-hour autopilot are built and tested, and switched off for now, so the news, replies and study status stop at the last collection (4 November 2026). The app says so instead of passing old news off as new: the home screen reads "Prototype · data up to Wed Nov 4", and the study card says when it was last checked.

**In one sentence:** everything an education institution announces, from every official channel and the Saudi press, in one place, with what people said under each story and answers to what they ask most.

## The day before

1. **Open the app once.** Supabase's free plan pauses a project after a week without visits, and the app then shows only what each phone kept (a phone that never opened it shows nothing). If the institutions do not load, open the Supabase dashboard and restore the project (Project → Restore); it takes a few minutes. Following one institution with the bell keeps it awake: the phone then checks for new posts in the background.
2. **Decide on the data.** Shown as it is, the data stops at 4 November and the app says so. To bring it up to date once, put `SUPABASE_SECRET_KEY` in `collector/.env` and run `python autopilot.py --once` in `collector`: one round of every collector, then it stops; nothing runs on a schedule. X and Codex are the slow steps (`--skip x` leaves X out), so give it up to an hour.
3. **Turn off sign-ups** in the Supabase dashboard (Authentication → Sign In / Providers) if it is not done yet. Nobody watching will see it, but the app has no accounts and strangers should not be able to make one.

## Three minutes

1. **Home.** Two institutions, the Ministry of Education and Shaqra University, each with its newest news and the faces of the replies under its news. The idea: what you missed, from every channel at once, and what people said about it.
2. **The Ministry → News.** One event reported on X, the website and by the press is one story, with "Also reported by" naming each outlet. Open a story with replies: "What people said" shows every face with its share. Tap **Worried** to read only the worried replies. Under the summary: who wrote it (AI, from the public replies, without names) and **Report a mistake**.
3. **Info.** It is in the order people ask about things under the institution's posts: of 257 different replies, 40 asked whether study was suspended or online, 24 about exams and dates, 22 how to reach someone, none about statistics. So the page starts with the study card (here with "Not checked since…", since collection is paused), then the coming dates counting down, then where to ask (Tawasul, 19996: tap to call), then the apps and the numbers, each opening its source.
4. **Sources.** Every official channel the source protocol found, including the hidden ones: Shaqra's unlinked RSS feed and open data service, the Ministry's four apps.
5. **Arabic.** On an Arabic phone the whole app is Arabic, right to left (in the browser, add `?lang=ar` to the address).
6. **For those who need it.** The phone's largest text: nothing is cut off. TalkBack: each card is read as one item, the faces by name and share ("38% asking"), not by emoji.
7. **No connection.** Airplane mode: the pages opened before still show, with a line saying since when.

Point out what AI does and what it does not: it writes only the faces and the "What people said" summary. Every number, date and study announcement comes from plain code reading official sources, with its link.

## Questions for people who try it

- What did the app show you that you had missed this week?
- Would you open it instead of X, or alongside it? Why?
- Was anything wrong, unclear or hard to find? (Every "Report a mistake" and the About page's feedback button open the project's GitHub issue form; a build can point them at a form instead with `FEEDBACK_URL` in `app/config/live.json`.)
- Which tab would you open most: News, Info or Sources?
- Which institution or channel is missing?

## On a laptop or a projector

Mirror the phone's screen, or run the web app from `app`:

```powershell
flutter build web --release --dart-define-from-file=config/live.json
python -m http.server 8790 --directory build\web
```

then open `http://localhost:8790` (add `?lang=ar` for Arabic) and narrow the window to phone width. Without `config/live.json` the same commands build the demo with made-up institutions.

## What the prototype does not do yet

- **New data.** Nothing arrives until the collectors run again (above). The bell can still be turned on; it says that no news will come while collection is paused.
- **More institutions.** Two are collected; the regional education departments, which announce most study changes, are not yet.
- **iPhone.** Android and the browser only.
- **An official service.** It is a student project, and the About page says so.

What would make it ready for the public at large is listed under "Is it ready?" in [RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md).
