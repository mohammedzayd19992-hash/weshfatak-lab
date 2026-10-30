import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'app_name.dart';
import 'brand.dart';
import 'config.dart';
import 'lab_preview.dart';
import 'data.dart';
import 'news_alerts.dart';
import 'screens/post_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/welcome_screen.dart';

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
  if (!isConfigured) {
    runApp(const LabPreviewApp());
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  // Signs people in from the confirmation email link (see authRedirectUrl).
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  final state = AppState(prefs)..onMessage = _showMessage;
  runApp(
    AppScope(
      state: state,
      child: UniNewsApp(
        startWithWelcome: !state.welcomeDone && !state.signedIn,
      ),
    ),
  );
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
          'Could not start news alerts. Open News alerts to try again.',
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
      'Could not open this story. Check your connection and try again.',
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
  const UniNewsApp({super.key, required this.startWithWelcome});

  final bool startWithWelcome;

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: appName,
    builder: (context, child) => Banner(
      message: 'IN DEVELOPMENT',
      location: BannerLocation.topEnd,
      child: child!,
    ),
    navigatorKey: _navigator,
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    scaffoldMessengerKey: _messenger,
    home: startWithWelcome ? const WelcomeScreen() : const FeedScreen(),
  );
}
