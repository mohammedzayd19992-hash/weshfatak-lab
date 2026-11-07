// Plain Dart classes for the rows the app reads from the database.

import 'l10n.dart';

/// A number from the database: PostgREST sends `numeric` columns as text.
double? _number(Object? value) => value is num
    ? value.toDouble()
    : value is String
    ? double.tryParse(value)
    : null;

DateTime? _time(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

/// A `date` column ("2026-11-20") as that day, without a time zone.
DateTime? _day(Object? value) {
  final day = value is String ? DateTime.tryParse(value) : null;
  return day == null ? null : DateTime(day.year, day.month, day.day);
}

/// How many opinions show each face, from a `{"happy": 3, "angry": 1}` column.
Map<String, int> emotionCounts(Object? json) => {
  for (final entry in (json as Map? ?? const {}).entries)
    entry.key as String: (entry.value as num).toInt(),
};

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

/// One row of the `news_cards` view: a post with its source, images, note and mood.
class NewsPost {
  const NewsPost({
    required this.id,
    required this.body,
    required this.publishedAt,
    required this.sourceUrl,
    required this.sourceName,
    required this.sourceType,
    required this.organization,
    this.organizationId,
    this.platform = 'website',
    this.handle,
    this.avatarUrl,
    this.media = const [],
    this.replyCount = 0,
    this.communityNote,
    this.emotions = const {},
    this.alsoIn = const [],
  });

  factory NewsPost.fromMap(Map<String, dynamic> map) => NewsPost(
    id: (map['news_id'] as num).toInt(),
    body: map['body'] as String,
    publishedAt: DateTime.parse(map['published_at'] as String).toLocal(),
    sourceUrl: map['source_url'] as String,
    sourceName: map['source_name'] as String,
    sourceType: map['source_type'] as String? ?? 'website',
    organization: map['organization'] as String,
    organizationId: (map['organization_id'] as num?)?.toInt(),
    platform: map['platform'] as String? ?? 'website',
    handle: map['handle'] as String?,
    avatarUrl: map['avatar_url'] as String?,
    media: [
      for (final item in map['media'] as List? ?? const [])
        NewsMedia.fromMap(Map<String, dynamic>.from(item as Map)),
    ],
    replyCount: (map['reply_count'] as num?)?.toInt() ?? 0,
    communityNote: map['community_note'] == null
        ? null
        : CommunityNote.fromMap(
            Map<String, dynamic>.from(map['community_note'] as Map),
          ),
    emotions: emotionCounts(map['emotions']),
    alsoIn: [
      for (final item in map['also_in'] as List? ?? const [])
        StoryCopy.fromMap(Map<String, dynamic>.from(item as Map)),
    ],
  );

  final int id;
  final String body;
  final DateTime publishedAt;
  final String sourceUrl;
  final String sourceName;
  final String sourceType; // website, rss, social or press
  final String organization;
  final int? organizationId;
  final String platform; // x, website, rss, youtube, media (the press), ...
  final String? handle;
  final String? avatarUrl;
  final List<NewsMedia> media;
  final int replyCount; // public replies collected from X
  final CommunityNote? communityNote; // null until the notes writer has run
  final Map<String, int> emotions; // faces of the replies
  final List<StoryCopy>
  alsoIn; // the same story from the institution's other channels and the press

  /// The original post's address without the "#preview-1" style marker.
  String get sourceLink => sourceUrl.split('#').first;
  bool get isFromX =>
      sourceLink.contains('x.com') || sourceLink.contains('twitter.com');

  /// A newspaper's or SPA's report, not the institution's own channel.
  bool get isPress => sourceType == 'press';
}

/// The same story as reported by another source (`also_in` of `news_cards`).
class StoryCopy {
  const StoryCopy({
    required this.sourceName,
    required this.url,
    this.platform = 'website',
    this.sourceType = 'website',
  });

  factory StoryCopy.fromMap(Map<String, dynamic> map) => StoryCopy(
    sourceName: map['source_name'] as String? ?? '',
    url: map['url'] as String,
    platform: map['platform'] as String? ?? 'website',
    sourceType: map['source_type'] as String? ?? 'website',
  );

  final String sourceName; // the outlet for a press report
  final String url;
  final String platform;
  final String sourceType;

  bool get isPress => sourceType == 'press';
}

/// What people said under a post (`community_notes`), summarized by AI from the public
/// replies.
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
    this.emotion,
  });

  factory PublicReply.fromMap(Map<String, dynamic> map) => PublicReply(
    id: (map['reply_id'] as num).toInt(),
    body: map['body'] as String,
    postedAt: DateTime.parse(map['posted_at'] as String).toLocal(),
    likes: (map['like_count'] as num?)?.toInt() ?? 0,
    emotion: map['emotion'] as String?,
  );

  final int id;
  final String body;
  final DateTime postedAt;
  final int likes;
  final String? emotion; // null until Claude has read it
}

/// One row of `institution_cards`: the Ministry of Education or a university, with its newest
/// post, its counts and how people reacted to its news.
class Institution {
  const Institution({
    required this.id,
    required this.name,
    this.nameAr,
    this.kind = 'university',
    this.city,
    this.foundedYear,
    this.websiteUrl,
    this.about,
    this.logoUrl,
    this.postCount = 0,
    this.lastPostAt,
    this.latestBody,
    this.sourceCount = 0,
    this.statCount = 0,
    this.emotions = const {},
    this.replyCount = 0,
    this.reviewCount = 0,
    this.reviewRating,
  });

  factory Institution.fromMap(Map<String, dynamic> map) => Institution(
    id: (map['organization_id'] as num).toInt(),
    name: map['name'] as String,
    nameAr: map['name_ar'] as String?,
    kind: map['kind'] as String? ?? 'university',
    city: map['city'] as String?,
    foundedYear: (map['founded_year'] as num?)?.toInt(),
    websiteUrl: map['website_url'] as String?,
    about: map['about'] as String?,
    logoUrl: map['logo_url'] as String?,
    postCount: (map['post_count'] as num?)?.toInt() ?? 0,
    lastPostAt: _time(map['last_post_at']),
    latestBody: map['latest_body'] as String?,
    sourceCount: (map['source_count'] as num?)?.toInt() ?? 0,
    statCount: (map['stat_count'] as num?)?.toInt() ?? 0,
    emotions: emotionCounts(map['emotions']),
    replyCount: (map['reply_count'] as num?)?.toInt() ?? 0,
    reviewCount: (map['review_count'] as num?)?.toInt() ?? 0,
    reviewRating: _number(map['review_rating']),
  );

  final int id;
  final String name; // English
  final String? nameAr;
  final String kind; // ministry, university or college
  final String? city;
  final int? foundedYear;
  final String? websiteUrl;
  final String? about; // in Arabic
  final String? logoUrl;
  final int postCount;
  final DateTime? lastPostAt;
  final String? latestBody; // its newest post
  final int sourceCount;
  final int statCount;
  final Map<String, int> emotions; // faces of the replies under its news
  final int replyCount;
  final int reviewCount; // written reviews of its apps, shown on its Info page
  final double? reviewRating; // average stars of the collected reviews

  /// The name in the app's language, and the other one.
  String get displayName => isArabic ? nameAr ?? name : name;
  String? get otherName => isArabic ? name : nameAr;

  String get kindLabel => switch (kind) {
    'ministry' => tr('Ministry', 'وزارة'),
    'college' => tr('College', 'كلية'),
    _ => tr('University', 'جامعة'),
  };
}

/// One bar of a statistic's breakdown.
class StatBar {
  const StatBar(this.label, this.value);

  final String label;
  final double value;
}

/// One statistic (`institution_stats`), with its period and the link it came from.
class InstitutionStat {
  const InstitutionStat({
    required this.section,
    required this.label,
    required this.value,
    required this.period,
    required this.sourceName,
    required this.sourceUrl,
    this.unit,
    this.breakdown = const [],
  });

  factory InstitutionStat.fromMap(Map<String, dynamic> map) => InstitutionStat(
    section: map['section'] as String,
    label: map['label'] as String,
    value: _number(map['value']) ?? 0,
    unit: map['unit'] as String?,
    period: map['period'] as String,
    breakdown: [
      for (final bar in map['breakdown'] as List? ?? const [])
        StatBar((bar as Map)['label'] as String, _number(bar['value']) ?? 0),
    ],
    sourceName: map['source_name'] as String,
    sourceUrl: map['source_url'] as String,
  );

  final String section; // people, study, digital or research
  final String label; // in Arabic
  final double value;
  final String? unit; // '%', '/5' or null for a count
  final String period;
  final List<StatBar> breakdown;
  final String sourceName;
  final String sourceUrl;
}

/// The Info page's sections, in the order used when nothing says otherwise.
const infoKinds = ['status', 'dates', 'help', 'apps', 'numbers'];

/// Where one section of an institution's Info page goes (`info_sections`), and how many replies
/// under its posts asked about it in the last 30 days. collector/info.py rewrites it on every run.
class InfoSection {
  const InfoSection({
    required this.kind,
    required this.position,
    this.asked = 0,
    this.note,
    this.checkedAt,
  });

  factory InfoSection.fromMap(Map<String, dynamic> map) => InfoSection(
    kind: map['kind'] as String,
    position: (map['position'] as num).toInt(),
    asked: (map['asked'] as num?)?.toInt() ?? 0,
    note: map['note'] as String?,
    checkedAt: _time(map['checked_at']),
  );

  final String kind; // status, dates, help, apps or numbers
  final int position; // 1 is shown first
  final int asked;
  final String? note; // one line under the title, in Arabic
  final DateTime? checkedAt; // when the collector last looked
}

/// One line of an Info section (`info_items`): an announcement about study, a date of the
/// academic calendar, or an official channel to ask.
class InfoItem {
  const InfoItem({
    required this.kind,
    required this.title,
    required this.sourceName,
    required this.sourceUrl,
    this.detail,
    this.startsOn,
    this.endsOn,
    this.publishedAt,
    this.link,
  });

  factory InfoItem.fromMap(Map<String, dynamic> map) => InfoItem(
    kind: map['kind'] as String,
    title: map['title'] as String,
    detail: map['detail'] as String?,
    startsOn: _day(map['starts_on']),
    endsOn: _day(map['ends_on']),
    publishedAt: _time(map['published_at']),
    link: map['link'] as String?,
    sourceName: map['source_name'] as String,
    sourceUrl: map['source_url'] as String,
  );

  final String kind; // status, dates or help
  final String title; // in Arabic
  final String? detail;
  final DateTime? startsOn; // dates
  final DateTime? endsOn; // dates that last more than a day
  final DateTime? publishedAt; // status: when the post or report came out
  final String? link; // https://, tel: or mailto:
  final String sourceName;
  final String sourceUrl;

  /// The last day a date lasts (its first, when it is one day).
  DateTime? get lastDay => endsOn ?? startsOn;
}

/// An institution's Info page as collector/info.py left it: its sections in order and their items.
/// Empty on a database without those tables yet; the page then keeps its usual order.
class InfoPage {
  const InfoPage({this.sections = const [], this.items = const []});

  final List<InfoSection> sections;
  final List<InfoItem> items;

  /// Whether the order came from what people asked.
  bool get ranked => sections.isNotEmpty;

  /// Most asked first; sections the collector has not written yet keep their usual place; the
  /// numbers always last.
  List<String> get order {
    final known = [...sections]
      ..sort((a, b) => a.position.compareTo(b.position));
    final order = [
      for (final section in known)
        if (infoKinds.contains(section.kind) && section.kind != 'numbers')
          section.kind,
    ];
    for (final kind in infoKinds) {
      if (!order.contains(kind) && kind != 'numbers') order.add(kind);
    }
    return [...order, 'numbers'];
  }

  InfoSection? section(String kind) {
    for (final section in sections) {
      if (section.kind == kind) return section;
    }
    return null;
  }

  List<InfoItem> itemsOf(String kind) => [
    for (final item in items)
      if (item.kind == kind) item,
  ];
}

/// A channel the source protocol found for an institution (`sources`).
class NewsSource {
  const NewsSource({
    required this.name,
    required this.platform,
    required this.role,
    required this.status,
    required this.url,
    this.handle,
    this.note,
  });

  factory NewsSource.fromMap(Map<String, dynamic> map) => NewsSource(
    name: map['name'] as String,
    platform: map['platform'] as String? ?? 'website',
    role: map['role'] as String? ?? 'news',
    status: map['status'] as String? ?? 'collected',
    url: map['url'] as String,
    handle: map['handle'] as String?,
    note: map['note'] as String?,
  );

  final String name;
  final String platform;
  final String role; // news, opinions or stats
  final String status; // collected, planned, manual or unavailable
  final String url;
  final String? handle;
  final String? note; // in Arabic: how it was found or why it waits
}

/// A written review of one of an institution's official apps (`review_cards`). No author.
class AppReview {
  const AppReview({
    required this.id,
    required this.body,
    required this.rating,
    required this.appName,
    required this.postedAt,
    this.title,
  });

  factory AppReview.fromMap(Map<String, dynamic> map) => AppReview(
    id: (map['review_id'] as num).toInt(),
    title: map['title'] as String?,
    body: map['body'] as String,
    rating: (map['rating'] as num).toInt(),
    appName: map['app_name'] as String,
    postedAt: DateTime.parse(map['posted_at'] as String).toLocal(),
  );

  final int id;
  final String? title;
  final String body;
  final int rating; // 1 to 5 stars
  final String appName;
  final DateTime postedAt;
}
