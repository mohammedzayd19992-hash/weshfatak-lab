import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data.dart';
import 'models.dart';
import 'news_alerts.dart';

/// App-wide state: the account, the member's profile and the saved feed filters.
class AppState extends ChangeNotifier {
  AppState(this._prefs)
    : filters = _readFilters(_prefs),
      welcomeDone = _prefs.getBool(_welcomeKey) ?? false {
    final auth = Supabase.instance.client.auth;
    _userId = auth.currentUser?.id;
    if (_userId != null) reloadProfile();
    _authSubscription = auth.onAuthStateChange.listen(
      (event) {
        final id = event.session?.user.id;
        if (id == _userId) return;
        _userId = id;
        profile = null;
        notifyListeners();
        if (id != null) reloadProfile();
      },
      // Failed email links (and offline token refreshes) arrive here.
      onError: (Object error) {
        final message = _linkErrorMessage(error);
        if (message != null) onMessage?.call(message);
      },
    );
  }

  /// Shows a short message on whichever screen is open (set by the app).
  ValueChanged<String>? onMessage;

  static String? _linkErrorMessage(Object error) {
    if (error is! AuthException) return null;
    final text = '${error.code} ${error.statusCode} ${error.message}'
        .toLowerCase();
    if (text.contains('expired')) {
      return 'That email link has expired. Sign in to get a new one.';
    }
    // The link was opened somewhere other than the phone that created the
    // account: the email is confirmed, but signing in needs the password.
    if (text.contains('code verifier') || text.contains('flow_state')) {
      return 'Your email is confirmed. Sign in with your email and password.';
    }
    return null;
  }

  static const _filtersKey = 'uninews.filters.v2';
  static const _welcomeKey = 'uninews.welcome_done';

  final SharedPreferences _prefs;
  late final NewsAlerts alerts = NewsAlerts(_prefs);
  late final StreamSubscription<AuthState> _authSubscription;
  String? _userId;

  FeedFilters filters;
  bool welcomeDone;
  Profile? profile;
  Map<String, List<String>> tagGroups = const {};

  User? get user => Supabase.instance.client.auth.currentUser;
  bool get signedIn => user != null;

  String get displayName =>
      profile?.displayName ??
      user?.userMetadata?['display_name'] as String? ??
      user?.email?.split('@').first ??
      'Member';

  List<String> get audiences =>
      tagGroups['audience'] ??
      const ['Students', 'Teaching Staff', 'Administrative Staff'];
  List<String> get categories =>
      tagGroups['category'] ??
      const ['Academic', 'Administrative', 'Activities', 'Exams'];

  /// Tag names for the filters. Keeps the defaults when offline.
  Future<void> loadChoices() async {
    try {
      tagGroups = await UniNewsApi.tags();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> reloadProfile() async {
    final id = _userId;
    if (id == null) return;
    try {
      final loaded = await UniNewsApi.profile(id);
      if (id != _userId) return;
      profile = loaded;
      notifyListeners();
    } catch (_) {}
  }

  void setProfile(Profile value) {
    profile = value;
    notifyListeners();
  }

  void setFilters(FeedFilters next) {
    filters = next;
    _prefs.setString(_filtersKey, jsonEncode(next.toJson()));
    notifyListeners();
  }

  void finishWelcome() {
    welcomeDone = true;
    _prefs.setBool(_welcomeKey, true);
  }

  Future<void> signOut() => Supabase.instance.client.auth.signOut();

  @override
  void dispose() {
    _authSubscription.cancel();
    alerts.dispose();
    super.dispose();
  }

  static FeedFilters _readFilters(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_filtersKey);
      if (raw == null) return const FeedFilters();
      return FeedFilters.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const FeedFilters();
    }
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
