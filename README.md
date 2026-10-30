# WeshFatak · وش فاتك — Lab submission

**IN DEVELOPMENT — educational prototype, not production-ready.**

WeshFatak brings education news into one feed. The full development source includes audience/category filters, article media, comments, community summaries and saved Android news alerts. These connected features require a backend and are not enabled in the default lab preview.

This lab edition opens an **offline preview with fictional content**. It does not initialize Supabase, sign anyone in, load real posts, or schedule news alerts. No live credentials, user records, saved browser sessions, import archives, or original Git history are included. The visible preview is deliberately limited; it is not a demonstration of every connected feature.

## GitHub link

https://github.com/mohammedzayd19992-hash/weshfatak-lab

## Resource folder information

| Folder | Contents |
| --- | --- |
| `app/lib/` | Flutter application source; `lab_preview.dart` is the default offline preview |
| `app/assets/icon/` | Application logo |
| `app/android/` | Android project and background notification code |
| `app/web/` | Web bootstrap and icons |
| `app/test/` | Flutter tests |
| `database/` | Schema, starter organization/tags and transactional checks; no database export |
| `collector/` | Optional development scripts and synthetic tests; no browser profile or collected data |

## Run and deployment method

Install Flutter with Dart compatible with `app/pubspec.yaml` (Dart 3.13.3 or later within major version 3), Git, and Chrome. For Android, also install Android Studio/SDK and Java 17.

```sh
git clone https://github.com/mohammedzayd19992-hash/weshfatak-lab.git
cd weshfatak-lab/app
flutter pub get
flutter run -d chrome
```

Build the offline browser preview:

```sh
flutter build web --release
```

Serve the resulting `app/build/web/` directory with a static HTTP server. For example, from `app/`: `python -m http.server 8080 --directory build/web`, then open http://localhost:8080. This repository supplies source and deployment instructions; it does not promise a hosted website.

Android: connect an emulator or USB debugging device and run `flutter run`. To build a test APK run `flutter build apk --debug`; output is `app/build/app/outputs/flutter-apk/app-debug.apk`. The lab uses application ID `com.weshfatak.lab`, so it does not replace the original app. No signing keys are supplied. If Gradle wrappers need regenerating, run `flutter create --platforms=android .` in a disposable checkout and review generated changes.

## Optional connected development

Use a **new disposable Supabase project**, never the original live database. Run `database/schema.sql`, then `database/seed.sql`, in its SQL editor. The included SQL is development source, not a verified production security configuration. Run `database/checks.sql` only in that disposable project. Use invented identities and synthetic content only. Review access policies before enabling any external access.

Pass your lab project's URL and publishable key explicitly:

```sh
flutter run --dart-define=SUPABASE_URL=https://YOUR-PROJECT-REF.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_LAB_PUBLISHABLE_KEY
```

For Android email callbacks, configure `weshfataklab://login-callback` on the disposable project. Never supply a secret/service-role key to the client. No backend is needed for the default preview.

## Limitations

This is a student development project, not an official Ministry service. Production readiness, real-device notification delivery, moderation, account deletion and privacy operations remain unfinished. Community summaries can be inaccurate. Do not enter real personal data in a lab backend. See `SHARING.md` for export scope and validation limits.
