// Supply a separate disposable lab backend explicitly. No production defaults.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);
const authRedirectUrl = 'weshfataklab://login-callback';
bool get isConfigured =>
    supabaseUrl.startsWith('https://') &&
    supabasePublishableKey.startsWith('sb_publishable_');
