import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'models.dart';

class SavedNewsAlert {
  const SavedNewsAlert({
    required this.id,
    required this.filters,
    required this.since,
    this.enabled = true,
    this.importantOnly = true,
  });

  factory SavedNewsAlert.fromJson(Map<String, dynamic> json) => SavedNewsAlert(
    id: json['id'] as String,
    filters: FeedFilters.fromJson(
      Map<String, dynamic>.from(json['filters'] as Map),
    ),
    since: json['since'] as String,
    enabled: json['enabled'] as bool? ?? true,
    importantOnly: json['importantOnly'] as bool? ?? true,
  );

  final String id;
  final FeedFilters filters;
  final String since;
  final bool enabled;
  final bool importantOnly;

  Map<String, dynamic> toJson() => {
    'id': id,
    'filters': filters.toJson(),
    'since': since,
    'enabled': enabled,
    'importantOnly': importantOnly,
  };

  SavedNewsAlert withEnabled(bool value) => SavedNewsAlert(
    id: id,
    filters: filters,
    importantOnly: importantOnly,
    enabled: value,
    since: value ? DateTime.now().toUtc().toIso8601String() : since,
  );

  bool sameFilter(FeedFilters other, bool important) =>
      importantOnly == important &&
      setEquals(filters.audiences, other.audiences) &&
      setEquals(filters.categories, other.categories);
}

class NewsAlerts extends ChangeNotifier {
  NewsAlerts(this._prefs) {
    try {
      _saved = [
        for (final item in jsonDecode(_prefs.getString(_key) ?? '[]') as List)
          SavedNewsAlert.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } catch (_) {
      _saved = [];
    }
  }

  static const channel = MethodChannel('weshfatak/news_alerts');
  static const _key = 'weshfatak.alerts.v1';
  final SharedPreferences _prefs;
  List<SavedNewsAlert> _saved = [];
  List<SavedNewsAlert> get saved => List.unmodifiable(_saved);
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> sync() async {
    if (!supported) return;
    await channel.invokeMethod<void>('sync', {
      'url': supabaseUrl,
      'key': supabasePublishableKey,
      'alerts': jsonEncode([for (final item in _saved) item.toJson()]),
    });
  }

  Future<bool> permission({bool request = false}) async =>
      supported &&
      (await channel.invokeMethod<bool>(
            request ? 'requestPermission' : 'permission',
          ) ??
          false);

  Future<void> add(FeedFilters filters, {required bool importantOnly}) async {
    if (_saved.any((item) => item.sameFilter(filters, importantOnly))) {
      throw StateError('This filter is already saved.');
    }
    if (_saved.length >= 10) {
      throw StateError('You can save up to 10 news alerts.');
    }
    final now = DateTime.now().toUtc();
    _saved = [
      ..._saved,
      SavedNewsAlert(
        id: now.microsecondsSinceEpoch.toString(),
        filters: FeedFilters.fromJson(filters.toJson()),
        since: now.toIso8601String(),
        importantOnly: importantOnly,
      ),
    ];
    await _save();
  }

  Future<void> toggle(String id, bool enabled) async {
    _saved = [
      for (final item in _saved)
        item.id == id ? item.withEnabled(enabled) : item,
    ];
    await _save();
  }

  Future<void> remove(String id) async {
    _saved = _saved.where((item) => item.id != id).toList();
    await _save();
  }

  Future<void> _save() async {
    await _prefs.setString(
      _key,
      jsonEncode([for (final item in _saved) item.toJson()]),
    );
    notifyListeners();
    await sync();
  }
}
