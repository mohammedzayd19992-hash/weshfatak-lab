import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'app_name.dart';
import 'brand.dart';
import 'config.dart';
import 'data.dart';
import 'l10n.dart';
import 'news_alerts.dart';
import 'screens/home_screen.dart';
import 'screens/post_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final prefs = await SharedPreferences.getInstance();
  UniNewsApi.keepOn(prefs);
  // Without a Supabase project (config.dart) the app runs the demo and never touches the network.
  if (isConfigured) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
      // The app has no accounts: it never signs in, so it reads no sign-in links either.
      authOptions: const FlutterAuthClientOptions(
        detectSessionInUri: false,
        autoRefreshToken: false,
        persistSession: false,
      ),
    );
  }
  final state = AppState(prefs);
  runApp(AppScope(state: state, child: const UniNewsApp()));
  if (state.alerts.supported) {
    NewsAlerts.channel.setMethodCallHandler((call) async {
      if (call.method == 'openPost' && call.arguments is int) {
        await _openAlertPost(call.arguments as int);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await state.alerts.sync();
        final id = await NewsAlerts.channel.invokeMethod<int>('launchPost');
        if (id != null) await _openAlertPost(id);
      } catch (_) {
        _showMessage(
          tr(
            'Could not start news alerts. Open News alerts to try again.',
            'تعذر تشغيل تنبيهات الأخبار. افتح التنبيهات وحاول مرة أخرى.',
          ),
        );
      }
    });
  }
}

final _messenger = GlobalKey<ScaffoldMessengerState>();
final _navigator = GlobalKey<NavigatorState>();

Future<void> _openAlertPost(int id) async {
  try {
    final post = await UniNewsApi.post(id);
    _navigator.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => PostScreen(post: post)),
    );
  } catch (_) {
    _showMessage(
      tr(
        'Could not open this story. Check your connection and try again.',
        'تعذر فتح الخبر. تحقق من اتصالك وحاول مرة أخرى.',
      ),
    );
  }
}

void _showMessage(String text) {
  // Wait for a frame so a message sent while the app is starting still shows.
  WidgetsBinding.instance
    ..addPostFrameCallback(
      (_) =>
          _messenger.currentState?.showSnackBar(SnackBar(content: Text(text))),
    )
    ..scheduleFrame();
}

class UniNewsApp extends StatelessWidget {
  const UniNewsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: appName,
    navigatorKey: _navigator,
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    scaffoldMessengerKey: _messenger,
    // Arabic phones get Arabic text and a right-to-left layout.
    locale: appLocale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const HomeScreen(),
  );
}
