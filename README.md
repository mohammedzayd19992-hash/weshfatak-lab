# WeshFatak · وش فاتك

**Status: a student project, version 1.8.0, a prototype.** It works end to end on real data, but the data is a snapshot: the collectors and the 2.5-hour autopilot are built and tested and on hold for now, so the news, replies and study status stop at the last collection (4 November 2026). The app says so: its home screen reads "Prototype · data up to Wed Nov 4". How to show it is in [DEMO.md](DEMO.md). It is not on Google Play yet and it is not an official Ministry service; what is still missing for the public at large is under "Is it ready?" in [RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md).

WeshFatak shows the news of Saudi education institutions and what people said about each piece of it. The home screen lists the institutions (the Ministry of Education, Shaqra University, …), each with its latest news and how people replied to its news. Each institution has its own page with three tabs:

- **News**: its news from every channel, not only X: its X account, YouTube channel and website (through the RSS feed, or Google News where the site has no feed), and what SPA and the Saudi papers (Sabq, Okaz, Al-Madina, Ajel, …) report about it. An event reported by several of them is one story, with "Also reported by" links to each source. Under each story, "What people said" shows the faces of the replies (😄 happy, 🤔 asking, 😐 neutral, 😟 worried, 🙃 sarcastic, 😢 sad, 😠 angry) and a short summary AI writes of them. Opening a story shows every face with its share; tap one to read only those replies.
- **Info**: the answers to what people ask under its posts, most asked first: whether study is suspended or online (the newest official word from the last week), the coming dates of its academic calendar counting down, where to ask (the official channels that open a ticket or answer the phone), its apps' ratings and reviews, then its numbers. Everything shows its source and opens it.
- **Sources**: every channel found with [the source protocol](PROTOCOL.md), and whether it is collected yet.

`collector/autopilot.py` can keep all of it up to date by itself, every 2.5 hours (see [collector/README.md](collector/README.md)); for the prototype it is on hold, and `python autopilot.py --once` brings the data up to date once. The app reads everything from the database when a page opens, so new news, numbers and dates reach phones without a new APK.

There are no accounts, comments or tags: everything is public and read-only. The bell on an institution's page sends a notification for each of its new posts (up to ten institutions), checked by Android in the background every 15 minutes or longer. Arabic phones get the whole app in Arabic, right to left; in the browser, add `?lang=ar` to the address.

AI does one job, the faces and the "What people said" summary, and each summary has "Report a mistake"; every number, date and study announcement comes from plain code reading official sources, with its link.

## GitHub link

https://github.com/mohammedzayd19992-hash/weshfatak-lab

This public copy has the whole source but not the live database's address or keys, nor anything collected: see [SHARING.md](SHARING.md). Built without a database, the app opens a **demo** with two made-up institutions, so it runs straight after cloning.

## Resource folder information

| Folder | Contents |
| --- | --- |
| `app/lib/` | The Flutter app. `data.dart` is every database read (with the offline copies), `demo.dart` the made-up data of the demo, `screens/` and `widgets/` the pages |
| `app/test/` | Flutter tests, including the whole app at double text size in English and Arabic against Flutter's accessibility guidelines |
| `app/android/` | The Android project and the background news alerts (`NewsAlertWorker.kt`) |
| `app/config/` | `example.json`: the shape of the file that tells a build which Supabase project to read |
| `collector/` | The Python programs that collect news, replies, reviews, numbers and the Info page, have Codex read the replies, and run all of it every 2.5 hours |
| `database/` | The Supabase SQL: tables, security rules, functions and checks |
| `tools/` | `export_public.py`, which makes this public copy and refuses anything private |
| `DEMO.md` | How to show the prototype: the day before, a three-minute walkthrough, questions for testers |
| `PROTOCOL.md` | How every official channel of an institution is found and verified, and why the Info page is ordered as it is |
| `RELEASE-CHECKLIST.md` | What each version changed and what was checked |

## Run and deployment method

Install Flutter (Dart 3.13.3 or later), Git, and Chrome; for Android also Android Studio's SDK and Java 17.

**The demo, no database needed:**

```powershell
git clone https://github.com/mohammedzayd19992-hash/weshfatak-lab.git
cd weshfatak-lab\app
flutter pub get
flutter run -d chrome        # or a phone or emulator: flutter run
flutter test
```

**With your own Supabase project:**

1. In a new project's SQL Editor run, in this order: `database/schema.sql`, `seed.sql`, `migrate-to-institutions.sql`, `migrate-to-info.sql`, `migrate-close-accounts.sql`. Each check file tests the rules inside a transaction that is rolled back: `checks.sql` right after `seed.sql` (it still tests the members of that first version), `checks-info.sql` after `migrate-to-info.sql`; `migrate-close-accounts.sql` checks itself as it runs. In Authentication, turn off new sign-ups: the app has no accounts.
2. Copy `app/config/example.json` to `app/config/live.json` and put in your project's URL and **publishable** key (Project Settings → API Keys). Git ignores `live.json`. Two more settings may go there: `FEEDBACK_URL`, the page that "Report a mistake" and the About page's feedback button open (the GitHub issue form when it is not given; a form of your own works too, never a personal address), and `APP_STAGE` set to `release`, which takes away the prototype line.
3. Run or build with it:

   ```powershell
   flutter run --dart-define-from-file=config/live.json
   flutter build apk --release --split-per-abi --dart-define-from-file=config/live.json
   ```

   The phone APK is `app\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`. `flutter build web --release --dart-define-from-file=config/live.json` builds the web app into `app/build/web`.
4. For the collectors, copy `collector/.env.example` to `collector/.env`, fill in the same URL and key and the project's secret key, then follow [collector/README.md](collector/README.md).

The release APK is still signed with the Android debug certificate, for phone testing; see the readiness list in RELEASE-CHECKLIST.md before publishing on Google Play.

## Accessibility

- **Screen readers** (TalkBack, VoiceOver, the browser's): every card is read as one item with what it opens; headings mark each section; the faces are read by name and share ("38% asking"), not by emoji; star ratings, likes and counts are read as words; every button and link has a label; the demo and offline lines are announced when they appear.
- **Large text**: everything follows the phone's text size. Rows that would not fit (faces, numbers, dates, sources, replies) stack instead, so nothing is cut off at 200%.
- **Touch**: every target is at least 48 by 48 pixels; a refresh button sits beside pull-to-refresh, which screen reader users cannot do.
- **Motion and contrast**: animations stop when the phone asks for less motion; text passes the contrast check on the dark theme, and the face colors were chosen to stay apart for color-blind readers.
- `app/test/accessibility_test.dart` opens every page at double text size, in English and Arabic, and runs Flutter's guidelines for touch targets, labels and contrast on each.

## Offline and slow connections

Each page the app loads is kept on the phone. Opened again without a connection, or when the database does not answer within 15 seconds, the page shows what it showed last time with a line saying since when; the 20 most recently opened stories are kept with their replies. Back online, the line goes away on the next load.

## Security and privacy

- The app reads only. The database's rules let the public key read the news and nothing else: it cannot insert, change or delete a row in any table, and only three read-only functions are open to it. Saving goes through functions only the secret key can call, and that key lives only in `collector/.env`.
- Since 1.7.0 (`migrate-close-accounts.sql`), the tables left from the old accounts are closed: nobody can add comments or profiles, and the old profiles' names are no longer readable.
- The app opens only web, phone and email links, and Android opens no links into the app.
- Replies keep their text, time and likes, never who wrote them. The AI that reads them runs in Codex with no shell, web search, apps or file access, and a note that looks like it carries a key is not saved.
- Builds get the database's address and key from a file Git ignores, so neither is in the source.

## Supabase

The free plan pauses a project after a week without use, and the app then shows only what phones kept. With the autopilot on hold, only people opening the app keep it awake (and phones following an institution, which ask for new posts in the background). Open it at least once a week, and the day before showing it; if it does not load, restore the project from the dashboard (Project → Restore).
