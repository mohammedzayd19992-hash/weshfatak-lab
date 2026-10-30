import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

SupabaseClient get _db => Supabase.instance.client;

/// Every database call the app makes. The app reads news and writes only
/// comments and the member's own profile; the database rules enforce that.
class UniNewsApi {
  static const pageSize = 10;

  /// One page of the feed (the `feed_page` database function).
  static Future<List<NewsPost>> feedPage(
    FeedFilters filters, {
    int offset = 0,
  }) async {
    final rows = await _db.rpc(
      'feed_page',
      params: {
        'p_audiences': filters.audiences.toList(),
        'p_categories': filters.categories.toList(),
        'p_limit': pageSize,
        'p_offset': offset,
      },
    );
    return [
      for (final row in rows as List)
        NewsPost.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }

  static Future<NewsPost> post(int newsId) async {
    final row = await _db
        .from('news_cards')
        .select()
        .eq('news_id', newsId)
        .single();
    return NewsPost.fromMap(row);
  }

  static Future<List<Comment>> comments(int newsId) async {
    final rows = await _db
        .from('comments')
        .select('comment_id, body, created_at, user_id, profiles(display_name)')
        .eq('news_id', newsId)
        .order(
          'created_at',
          ascending: true,
        ) // oldest first, like a conversation
        .order('comment_id', ascending: true);
    return rows.map(Comment.fromMap).toList();
  }

  /// Replies collected from X, most liked first.
  static Future<List<PublicReply>> replies(int newsId) async {
    final rows = await _db
        .from('public_replies')
        .select('reply_id, body, like_count, posted_at')
        .eq('news_id', newsId)
        .order('like_count', ascending: false)
        .order('posted_at', ascending: true);
    return rows.map(PublicReply.fromMap).toList();
  }

  /// The database fills in the author from the session.
  static Future<void> addComment(int newsId, String body) async {
    await _db.from('comments').insert({'news_id': newsId, 'body': body});
  }

  /// Tag names grouped by `tag_group` (audience, category), in database order.
  static Future<Map<String, List<String>>> tags() async {
    final rows = await _db
        .from('tags')
        .select('name, tag_group')
        .order('tag_id', ascending: true);
    final groups = <String, List<String>>{};
    for (final row in rows) {
      groups
          .putIfAbsent(row['tag_group'] as String, () => [])
          .add(row['name'] as String);
    }
    return groups;
  }

  static Future<Profile?> profile(String userId) async {
    final row = await _db
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }

  /// Every account gets a profile when it is created; insert covers older accounts.
  static Future<Profile> saveProfile(String userId, String name) async {
    final values = {'display_name': name};
    final updated = await _db
        .from('profiles')
        .update(values)
        .eq('user_id', userId)
        .select();
    if (updated.isNotEmpty) return Profile.fromMap(updated.first);
    final inserted = await _db
        .from('profiles')
        .insert({...values, 'user_id': userId})
        .select()
        .single();
    return Profile.fromMap(inserted);
  }
}
