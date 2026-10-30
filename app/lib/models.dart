// Plain Dart classes for the rows the app reads from the database.

/// Whose news the app shows (the one row of the `organizations` table).
const organizationName = 'Ministry of Education';

/// One image of a post (`news_media`).
class NewsMedia {
  const NewsMedia({required this.url, this.alt, this.width, this.height});

  factory NewsMedia.fromMap(Map<String, dynamic> map) => NewsMedia(
    url: map['url'] as String,
    alt: map['alt'] as String?,
    width: (map['width'] as num?)?.toInt(),
    height: (map['height'] as num?)?.toInt(),
  );

  final String url;
  final String? alt;
  final int? width;
  final int? height;

  double? get aspectRatio =>
      width != null && height != null && height! > 0 ? width! / height! : null;
}

/// One row of the `news_cards` view: a post with its source, tags and images.
class NewsPost {
  const NewsPost({
    required this.id,
    required this.body,
    required this.publishedAt,
    required this.sourceUrl,
    required this.sourceName,
    required this.sourceType,
    required this.organization,
    this.handle,
    this.avatarUrl,
    this.audience = const [],
    this.category = const [],
    this.media = const [],
    this.commentCount = 0,
    this.replyCount = 0,
    this.communityNote,
  });

  factory NewsPost.fromMap(Map<String, dynamic> map) => NewsPost(
    id: (map['news_id'] as num).toInt(),
    body: map['body'] as String,
    publishedAt: DateTime.parse(map['published_at'] as String).toLocal(),
    sourceUrl: map['source_url'] as String,
    sourceName: map['source_name'] as String,
    sourceType: map['source_type'] as String? ?? 'website',
    organization: map['organization'] as String,
    handle: map['handle'] as String?,
    avatarUrl: map['avatar_url'] as String?,
    audience: List<String>.from(map['audience'] as List? ?? const []),
    category: List<String>.from(map['category'] as List? ?? const []),
    media: [
      for (final item in map['media'] as List? ?? const [])
        NewsMedia.fromMap(Map<String, dynamic>.from(item as Map)),
    ],
    commentCount: (map['comment_count'] as num?)?.toInt() ?? 0,
    replyCount: (map['reply_count'] as num?)?.toInt() ?? 0,
    communityNote: map['community_note'] == null
        ? null
        : CommunityNote.fromMap(
            Map<String, dynamic>.from(map['community_note'] as Map),
          ),
  );

  final int id;
  final String body;
  final DateTime publishedAt;
  final String sourceUrl;
  final String sourceName;
  final String sourceType; // website, rss or social
  final String organization;
  final String? handle;
  final String? avatarUrl;
  final List<String> audience; // empty = for everyone
  final List<String> category;
  final List<NewsMedia> media;
  final int commentCount;
  final int replyCount; // public replies collected from X
  final CommunityNote? communityNote; // null until the notes writer has run

  /// The original post's address without the "#preview-1" style marker.
  String get sourceLink => sourceUrl.split('#').first;
  bool get isFromX =>
      sourceLink.contains('x.com') || sourceLink.contains('twitter.com');
}

/// What people said under a post (`community_notes`), summarized by Claude from the public
/// replies and app comments.
class CommunityNote {
  const CommunityNote({
    required this.summary,
    this.keyPoints = const [],
    required this.repliesRead,
  });

  factory CommunityNote.fromMap(Map<String, dynamic> map) => CommunityNote(
    summary: map['summary'] as String,
    keyPoints: List<String>.from(map['key_points'] as List? ?? const []),
    repliesRead: (map['replies_read'] as num?)?.toInt() ?? 0,
  );

  final String summary; // in Arabic
  final List<String> keyPoints; // issues, requests and questions people raised
  final int repliesRead;
}

/// A reply someone wrote under the post on X (`public_replies`). Who wrote it is never stored.
class PublicReply {
  const PublicReply({
    required this.id,
    required this.body,
    required this.postedAt,
    this.likes = 0,
  });

  factory PublicReply.fromMap(Map<String, dynamic> map) => PublicReply(
    id: (map['reply_id'] as num).toInt(),
    body: map['body'] as String,
    postedAt: DateTime.parse(map['posted_at'] as String).toLocal(),
    likes: (map['like_count'] as num?)?.toInt() ?? 0,
  );

  final int id;
  final String body;
  final DateTime postedAt;
  final int likes;
}

/// A comment with its author's display name.
class Comment {
  const Comment({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.userId,
    required this.authorName,
  });

  factory Comment.fromMap(Map<String, dynamic> map) => Comment(
    id: (map['comment_id'] as num).toInt(),
    body: map['body'] as String,
    createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    userId: map['user_id'] as String,
    authorName:
        (map['profiles'] as Map?)?['display_name'] as String? ?? 'Member',
  );

  final int id;
  final String body;
  final DateTime createdAt;
  final String userId;
  final String authorName;
}

/// The signed-in member's public profile: the name shown on their comments.
class Profile {
  const Profile({required this.userId, required this.displayName});

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
    userId: map['user_id'] as String,
    displayName: map['display_name'] as String,
  );

  final String userId;
  final String displayName;
}

/// What the feed shows: optional audiences and news tags.
class FeedFilters {
  const FeedFilters({this.audiences = const {}, this.categories = const {}});

  factory FeedFilters.fromJson(Map<String, dynamic> json) => FeedFilters(
    audiences: {...List<String>.from(json['audiences'] as List? ?? const [])},
    categories: {...List<String>.from(json['categories'] as List? ?? const [])},
  );

  final Set<String> audiences; // empty = all
  final Set<String> categories; // empty = all

  /// Filters chosen in the filter sheet (the audience chips live in the dock).
  int get sheetCount => categories.length;

  FeedFilters copyWith({Set<String>? audiences, Set<String>? categories}) =>
      FeedFilters(
        audiences: audiences ?? this.audiences,
        categories: categories ?? this.categories,
      );

  Map<String, dynamic> toJson() => {
    'audiences': audiences.toList(),
    'categories': categories.toList(),
  };
}
