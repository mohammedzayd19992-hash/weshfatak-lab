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
