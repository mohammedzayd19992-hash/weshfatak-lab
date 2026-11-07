// The Supabase project the app reads, given when the app is built so that no project address or key
// sits in the source, which is public:
//
//   flutter run --dart-define-from-file=config/live.json
//   flutter build apk --release --split-per-abi --dart-define-from-file=config/live.json
//
// config/live.json is never added to Git; config/example.json shows its shape. Only the publishable
// key goes there: it can do only what the database rules allow (read). Never the secret key.
// A build without them opens the demo: made-up institutions and news, no network (lib/demo.dart).
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

bool get isConfigured =>
    supabaseUrl.startsWith('https://') &&
    supabasePublishableKey.startsWith('sb_publishable_');

/// The version the About page shows. A test keeps it equal to pubspec.yaml's.
const appVersion = '1.8.0';

/// "prototype" (the default) says so on the home screen and the About page, with how old the data
/// is. A build for the public at large passes APP_STAGE=release.
const appStage = String.fromEnvironment('APP_STAGE', defaultValue: 'prototype');

bool get isPrototype => appStage == 'prototype';

/// Where people send feedback and report a mistake in a summary: the public repository's issue form
/// unless a build gives another page in FEEDBACK_URL (a form, for example). Never a personal address.
const feedbackUrl = String.fromEnvironment(
  'FEEDBACK_URL',
  defaultValue:
      'https://github.com/mohammedzayd19992-hash/weshfatak-lab/issues/new',
);

const sourceCodeUrl = 'https://github.com/mohammedzayd19992-hash/weshfatak-lab';
