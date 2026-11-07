import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'demo.dart' as demo;
import 'models.dart';

SupabaseClient get _db => Supabase.instance.client;

typedef Rows = List<Map<String, dynamic>>;

/// Every database call the app makes. The app only reads: the collectors write (collector/), and the
/// database rules enforce that.
///
/// Each answer is also kept on the phone, so a page opened without a connection shows what it showed
/// last time, and [offlineSince] says since when. A build without a Supabase project ([demoMode])
/// reads the made-up rows of demo.dart instead and never touches the network.
class UniNewsApi {
  static const pageSize = 10;

  /// How long a page waits for the database before it falls back to what was kept.
  static const timeout = Duration(seconds: 15);

  /// When a page shows kept rows because the database did not answer: the time they were kept.
  /// Null while the database answers.
  static final offlineSince = ValueNotifier<DateTime?>(null);

  static bool get demoMode => demoForTests ?? !isConfigured;

  /// Lets tests run the database path with a stand-in answer.
  @visibleForTesting
  static bool? demoForTests;

  @visibleForTesting
  static Future<Rows> rowsForTests(
    String key,
    Future<Object?> Function() ask,
  ) => _rows(key, ask, () => const []);

  @visibleForTesting
  static Future<void> rememberForTests(int newsId) => _remember(newsId);

  static SharedPreferences? _prefs;

  /// Where answers are kept between launches. main.dart calls this once.
  static void keepOn(SharedPreferences prefs) => _prefs = prefs;

  static const _prefix = 'weshfatak.kept.v1.';
  static const _postsKey = '${_prefix}posts';
  static const _mostPosts =
      20; // posts and their replies kept, most recently opened first

  /// The rows of one question: from the database (keeping them), else the kept ones, else the error.
  static Future<Rows> _rows(
    String key,
    Future<Object?> Function() ask,
    Rows Function() demoRows,
  ) async {
    if (demoMode) return demoRows();
    try {
      final rows = _asRows(await ask().timeout(timeout));
      offlineSince.value = null;
      unawaited(_keep(key, rows));
      return rows;
    } catch (_) {
      final kept = _kept(key);
      if (kept == null) rethrow;
      offlineSince.value = kept.at;
      return kept.rows;
    }
  }

  static Rows _asRows(Object? answer) => switch (answer) {
    final List<dynamic> list => [
      for (final row in list) Map<String, dynamic>.from(row as Map),
    ],
    final Map<dynamic, dynamic> one => [Map<String, dynamic>.from(one)],
    _ => [],
  };

  static Future<void> _keep(String key, Rows rows) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(
        '$_prefix$key',
        jsonEncode({
          'at': DateTime.now().toUtc().toIso8601String(),
          'rows': rows,
        }),
      );
    } catch (_) {
      // A full or unavailable store only means this page will not be there offline.
    }
  }

  static ({DateTime at, Rows rows})? _kept(String key) {
    final text = _prefs?.getString('$_prefix$key');
    if (text == null) return null;
    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      return (
        at: DateTime.parse(json['at'] as String).toLocal(),
        rows: _asRows(json['rows']),
      );
    } catch (_) {
      return null;
    }
  }

  /// Keeps the most recently opened posts only, so the store stays small.
  static Future<void> _remember(int newsId) async {
    final prefs = _prefs;
    if (prefs == null || demoMode) return;
    final ids = [
      newsId,
      for (final id in prefs.getStringList(_postsKey) ?? const <String>[])
        if (int.tryParse(id) case final old? when old != newsId) old,
    ];
    for (final old in ids.skip(_mostPosts)) {
      await prefs.remove('${_prefix}post.$old');
      await prefs.remove('${_prefix}replies.$old');
    }
    await prefs.setStringList(_postsKey, [
      for (final id in ids.take(_mostPosts)) '$id',
    ]);
  }

  /// The Ministry of Education and the universities, in home screen order.
  static Future<List<Institution>> institutions() async {
    final rows = await _rows(
      'institutions',
      () => _db
          .from('institution_cards')
          .select()
          .order('position', ascending: true),
      demo.institutions,
    );
    return rows.map(Institution.fromMap).toList();
  }

  /// One page of an institution's news (the `institution_feed_page` database function). Only the
  /// first page is kept for offline use.
  static Future<List<NewsPost>> feedPage(
    int institutionId, {
    int offset = 0,
  }) async {
    Future<Object?> ask() => _db.rpc(
      'institution_feed_page',
      params: {
        'p_organization_id': institutionId,
        'p_limit': pageSize,
        'p_offset': offset,
      },
    );
    Rows demoRows() => demo.feed(institutionId, offset, pageSize);
    final rows = offset == 0
        ? await _rows('feed.$institutionId', ask, demoRows)
        : demoMode
        ? demoRows()
        : _asRows(await ask().timeout(timeout));
    return rows.map(NewsPost.fromMap).toList();
  }

  static Future<NewsPost> post(int newsId) async {
    final rows = await _rows(
      'post.$newsId',
      () => _db.from('news_cards').select().eq('news_id', newsId).single(),
      () => [demo.post(newsId)],
    );
    unawaited(_remember(newsId));
    return NewsPost.fromMap(rows.single);
  }

  /// Replies collected from X, most liked first.
  static Future<List<PublicReply>> replies(int newsId) async {
    final rows = await _rows(
      'replies.$newsId',
      () => _db
          .from('public_replies')
          .select('reply_id, body, like_count, posted_at, emotion')
          .eq('news_id', newsId)
          .order('like_count', ascending: false)
          .order('posted_at', ascending: true),
      () => demo.replies(newsId),
    );
    return rows.map(PublicReply.fromMap).toList();
  }

  /// The newest written reviews of the institution's apps.
  static Future<List<AppReview>> reviews(
    int institutionId, {
    int limit = 10,
  }) async {
    final rows = await _rows(
      'reviews.$institutionId',
      () => _db
          .from('review_cards')
          .select('review_id, title, body, rating, app_name, posted_at')
          .eq('organization_id', institutionId)
          .order('posted_at', ascending: false)
          .limit(limit),
      () => demo.reviews(institutionId),
    );
    return rows.map(AppReview.fromMap).toList();
  }

  static Future<List<InstitutionStat>> stats(int institutionId) async {
    final rows = await _rows(
      'stats.$institutionId',
      () => _db
          .from('institution_stats')
          .select()
          .eq('organization_id', institutionId)
          .order('position', ascending: true)
          .order('stat_id', ascending: true),
      () => demo.stats(institutionId),
    );
    return rows.map(InstitutionStat.fromMap).toList();
  }

  /// The Info page's order and its study, dates and help items (collector/info.py). A database
  /// without those tables yet, and a phone that never loaded them, give an empty page, so the app
  /// keeps its usual order.
  static Future<InfoPage> info(int institutionId) async {
    try {
      final (sections, items) = await (
        _rows(
          'info_sections.$institutionId',
          () => _db
              .from('info_sections')
              .select('kind, position, asked, note, checked_at')
              .eq('organization_id', institutionId),
          () => demo.infoSections(institutionId),
        ),
        _rows(
          'info_items.$institutionId',
          () => _db
              .from('info_items')
              .select(
                'kind, title, detail, starts_on, ends_on, published_at, link, source_name, source_url',
              )
              .eq('organization_id', institutionId)
              .order('position', ascending: true),
          () => demo.infoItems(institutionId),
        ),
      ).wait;
      return InfoPage(
        sections: sections.map(InfoSection.fromMap).toList(),
        items: items.map(InfoItem.fromMap).toList(),
      );
    } catch (_) {
      return const InfoPage();
    }
  }

  static Future<List<NewsSource>> sources(int institutionId) async {
    final rows = await _rows(
      'sources.$institutionId',
      () => _db
          .from('sources')
          .select('name, platform, role, status, url, handle, note')
          .eq('organization_id', institutionId)
          .order('source_id', ascending: true),
      () => demo.sources(institutionId),
    );
    return rows.map(NewsSource.fromMap).toList();
  }
}
