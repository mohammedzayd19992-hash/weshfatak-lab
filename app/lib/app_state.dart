import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'news_alerts.dart';

/// App-wide state: the institutions the phone follows. There are no accounts:
/// everything in the app is public, and follows stay on the phone.
class AppState extends ChangeNotifier {
  AppState(SharedPreferences prefs) : alerts = NewsAlerts(prefs) {
    alerts.addListener(notifyListeners);
  }

  final NewsAlerts alerts;

  @override
  void dispose() {
    alerts
      ..removeListener(notifyListeners)
      ..dispose();
    super.dispose();
  }
}

/// Makes [AppState] available to every screen and rebuilds them when it changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Reads the state without rebuilding when it changes (for callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
