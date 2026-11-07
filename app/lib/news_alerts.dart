import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// An institution whose new posts notify the phone.
class SavedNewsAlert {
  const SavedNewsAlert({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.since,
    this.enabled = true,
  });

  factory SavedNewsAlert.fromJson(Map<String, dynamic> json) => SavedNewsAlert(
    id: json['id'] as String,
    organizationId: (json['organizationId'] as num).toInt(),
    name: json['name'] as String,
    since: json['since'] as String,
    enabled: json['enabled'] as bool? ?? true,
  );

  final String id;
  final int organizationId;
  final String name; // shown in the alerts list
  final String since; // only posts collected after this are announced
  final bool enabled;

  Map<String, dynamic> toJson() => {
    'id': id,
    'organizationId': organizationId,
    'name': name,
    'since': since,
    'enabled': enabled,
  };

  SavedNewsAlert withEnabled(bool value) => SavedNewsAlert(
    id: id,
    organizationId: organizationId,
    name: name,
    enabled: value,
    since: value ? DateTime.now().toUtc().toIso8601String() : since,
  );
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
  // v1 held feed filters by audience and category, which the app no longer has.
  static const _key = 'weshfatak.alerts.v2';
  static const most = 10;
  final SharedPreferences _prefs;
  List<SavedNewsAlert> _saved = [];
  List<SavedNewsAlert> get saved => List.unmodifiable(_saved);

  /// Alerts need the Android app and a real database: the demo has nothing new to announce.
  bool get supported =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      isConfigured;

  SavedNewsAlert? alertFor(int organizationId) {
    for (final item in _saved) {
      if (item.organizationId == organizationId) return item;
    }
    return null;
  }

  bool follows(int organizationId) =>
      alertFor(organizationId)?.enabled ?? false;

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

  /// Starts announcing the institution's new posts, or resumes a paused alert.
  Future<void> follow(int organizationId, String name) async {
    final existing = alertFor(organizationId);
    if (existing != null) return toggle(existing.id, true);
    if (_saved.length >= most) {
      throw StateError('You can follow up to $most institutions.');
    }
    final now = DateTime.now().toUtc();
    _saved = [
      ..._saved,
      SavedNewsAlert(
        id: now.microsecondsSinceEpoch.toString(),
        organizationId: organizationId,
        name: name,
        since: now.toIso8601String(),
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
