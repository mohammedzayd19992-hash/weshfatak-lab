// The demo: what the app shows when it is built without a Supabase project (see config.dart), so
// anyone can open it from the public source. Everything here is made up: two invented institutions,
// their news, replies, dates and numbers. Every link goes to example.com, which belongs to no one.
// The rows have the same shape as the database's, so every screen runs exactly as it does for real.

import 'l10n.dart';

typedef Row = Map<String, dynamic>;

const oasis = 1;
const palm = 2;

String _ago(Duration time) =>
    DateTime.now().subtract(time).toUtc().toIso8601String();

String _day(int fromToday) {
  final day = DateTime.now().add(Duration(days: fromToday));
  return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
}

const _site = 'https://example.com';

List<Row> _posts() => [
  {
    'news_id': 101,
    'organization_id': oasis,
    'organization': 'Oasis University (demo)',
    'body': 'تعلن جامعة الواحة تحويل الدراسة يوم الأحد إلى التعليم عن بعد بسبب التقلبات الجوية، وتبقى الاختبارات في مواعيدها. (خبر تجريبي)',
    'published_at': _ago(const Duration(hours: 3)),
    'source_url': '$_site/oasis/x/101',
    'source_name': 'جامعة الواحة',
    'source_type': 'social',
    'platform': 'x',
    'handle': '@OasisUni_demo',
    'reply_count': 8,
    'emotions': {'asking': 3, 'worried': 2, 'happy': 2, 'angry': 1},
    'community_note': {
      'summary': 'سأل كثيرون هل يشمل القرار الاختبارات العملية، وقلق بعضهم من ضعف الإنترنت في السكن، وشكر آخرون الجامعة على الإعلان المبكر.',
      'key_points': [
        'هل يشمل القرار الاختبارات العملية؟',
        'ضعف الإنترنت في السكن الجامعي',
        'الشكر على الإعلان المبكر',
      ],
      'replies_read': 8,
    },
    'also_in': [
      {
        'source_name': 'جامعة الواحة',
        'platform': 'website',
        'source_type': 'website',
        'url': '$_site/oasis/news/101',
      },
      {
        'source_name': 'صحيفة المثال',
        'platform': 'media',
        'source_type': 'press',
        'url': '$_site/press/101',
      },
    ],
  },
  {
    'news_id': 102,
    'organization_id': oasis,
    'organization': 'Oasis University (demo)',
    'body': 'فتح التسجيل في برنامج الإرشاد الأكاديمي للطلاب المستجدين حتى نهاية الشهر عبر بوابة الطالب. (خبر تجريبي)',
    'published_at': _ago(const Duration(days: 2, hours: 4)),
    'source_url': '$_site/oasis/news/102',
    'source_name': 'جامعة الواحة',
    'source_type': 'website',
    'platform': 'website',
  },
  {
    'news_id': 103,
    'organization_id': oasis,
    'organization': 'Oasis University (demo)',
    'body': 'جامعة الواحة تطلق مركزًا للبحث في الطاقة المتجددة بالشراكة مع القطاع الخاص. (خبر تجريبي)',
    'published_at': _ago(const Duration(days: 5)),
    'source_url': '$_site/press/103',
    'source_name': 'صحيفة المثال',
    'source_type': 'press',
    'platform': 'media',
  },
  {
    'news_id': 201,
    'organization_id': palm,
    'organization': 'Palm Technical College (demo)',
    'body': 'تذكير: آخر موعد للحذف والإضافة يوم الخميس عبر بوابة المتدرب. (خبر تجريبي)',
    'published_at': _ago(const Duration(days: 1, hours: 2)),
    'source_url': '$_site/palm/x/201',
    'source_name': 'كلية النخلة التقنية',
    'source_type': 'social',
    'platform': 'x',
    'handle': '@PalmCollege_demo',
    'reply_count': 3,
    'emotions': {'asking': 2, 'angry': 1},
    'community_note': {
      'summary': 'طلب المتدربون تمديد الموعد، واشتكى أحدهم من بطء البوابة في بداية كل فصل.',
      'key_points': ['تمديد موعد الحذف والإضافة', 'بطء بوابة المتدرب'],
      'replies_read': 3,
    },
  },
  {
    'news_id': 202,
    'organization_id': palm,
    'organization': 'Palm Technical College (demo)',
    'body': 'ورشة عمل عن السلامة في المعامل يوم الثلاثاء القادم في القاعة الرئيسية. (خبر تجريبي)',
    'published_at': _ago(const Duration(days: 4)),
    'source_url': '$_site/palm/news/202',
    'source_name': 'كلية النخلة التقنية',
    'source_type': 'website',
    'platform': 'website',
  },
];

final _replies = <int, List<(String, String, int, Duration)>>{
  101: [
    (
      'هل الاختبار العملي يوم الأحد يكون عن بعد بعد؟',
      'asking',
      14,
      Duration(hours: 2, minutes: 50),
    ),
    (
      'الله يجزاكم خير على الإعلان المبكر',
      'happy',
      9,
      Duration(hours: 2, minutes: 40),
    ),
    (
      'الإنترنت في السكن ضعيف جدًا، كيف نحضر؟',
      'worried',
      7,
      Duration(hours: 2, minutes: 30),
    ),
    (
      'طيب والطلاب اللي عندهم مختبرات؟',
      'asking',
      5,
      Duration(hours: 2, minutes: 10),
    ),
    ('هالمرة الإعلان بدري، شكرًا', 'happy', 3, Duration(hours: 2)),
    (
      'خايفين يأثر على مواعيد الاختبارات النهائية',
      'worried',
      2,
      Duration(hours: 1, minutes: 40),
    ),
    ('متى ينزل رابط المحاضرة؟', 'asking', 2, Duration(hours: 1, minutes: 20)),
    ('كان المفروض يكون القرار للأسبوع كامل', 'angry', 1, Duration(hours: 1)),
  ],
  201: [
    ('ممكن تمديد يومين؟ البوابة كانت متوقفة', 'asking', 6, Duration(hours: 20)),
    ('البوابة بطيئة كل بداية فصل', 'angry', 4, Duration(hours: 19)),
    ('هل الحذف يؤثر على المكافأة؟', 'asking', 2, Duration(hours: 18)),
  ],
};

List<Row> institutions() {
  Row card(
    int id,
    String name,
    String nameAr,
    String kind,
    String city,
    int founded,
    String about,
  ) {
    final posts = _posts()
        .where((post) => post['organization_id'] == id)
        .toList();
    final emotions = <String, int>{};
    for (final post in posts) {
      (post['emotions'] as Map<String, int>? ?? const {}).forEach(
        (face, n) => emotions[face] = (emotions[face] ?? 0) + n,
      );
    }
    return {
      'organization_id': id,
      'name': name,
      'name_ar': nameAr,
      'kind': kind,
      'city': city,
      'founded_year': founded,
      'website_url': '$_site/${id == oasis ? 'oasis' : 'palm'}',
      'about': about,
      'post_count': posts.length,
      'last_post_at': posts.first['published_at'],
      'latest_body': posts.first['body'],
      'source_count': sources(id).length,
      'stat_count': stats(id).length,
      'emotions': emotions,
      'reply_count': emotions.values.fold(0, (sum, n) => sum + n),
      'review_count': reviews(id).length,
      'review_rating': id == oasis ? 3.5 : 4.0,
    };
  }

  return [
    card(
      oasis,
      'Oasis University (demo)',
      'جامعة الواحة (تجريبية)',
      'university',
      tr('Al Waha', 'الواحة'),
      1999,
      'جامعة من الخيال لعرض التطبيق: أخبارها وردود الناس ومواعيدها وأرقامها كلها أمثلة وليست حقيقية.',
    ),
    card(
      palm,
      'Palm Technical College (demo)',
      'كلية النخلة التقنية (تجريبية)',
      'college',
      tr('Al Nakhla', 'النخلة'),
      2008,
      'كلية من الخيال لعرض التطبيق، ولا يوجد إعلان عن الدراسة لديها هذا الأسبوع.',
    ),
  ];
}

List<Row> feed(int institutionId, int offset, int limit) => _posts()
    .where((post) => post['organization_id'] == institutionId)
    .skip(offset)
    .take(limit)
    .toList();

Row post(int newsId) => _posts().firstWhere(
  (post) => post['news_id'] == newsId,
  orElse: () => throw StateError('No demo post $newsId'),
);

List<Row> replies(int newsId) => [
  for (final (index, (body, face, likes, ago))
      in (_replies[newsId] ?? const []).indexed)
    {
      'reply_id': newsId * 100 + index,
      'body': body,
      'emotion': face,
      'like_count': likes,
      'posted_at': _ago(ago),
    },
];

List<Row> reviews(int institutionId) => switch (institutionId) {
  oasis => [
    {
      'review_id': 1,
      'title': 'يعلق عند رفع الواجبات',
      'body': 'التطبيق جميل لكنه يتوقف عند رفع ملف كبير، أتمنى إصلاحه قبل الاختبارات.',
      'rating': 2,
      'app_name': 'تطبيق الواحة (تجريبي)',
      'posted_at': _ago(const Duration(days: 3)),
    },
    {
      'review_id': 2,
      'title': 'سهل وسريع',
      'body': 'أعرف جدولي ودرجاتي بضغطة، ممتاز.',
      'rating': 5,
      'app_name': 'تطبيق الواحة (تجريبي)',
      'posted_at': _ago(const Duration(days: 9)),
    },
  ],
  _ => [
    {
      'review_id': 3,
      'title': null,
      'body': 'يؤدي الغرض، والإشعارات تصل متأخرة أحيانًا.',
      'rating': 4,
      'app_name': 'تطبيق النخلة (تجريبي)',
      'posted_at': _ago(const Duration(days: 6)),
    },
  ],
};

List<Row> stats(int institutionId) {
  final source = institutionId == oasis ? 'oasis' : 'palm';
  Row stat(
    String section,
    String label,
    num value,
    String? unit,
    String period, [
    List<Row> bars = const [],
  ]) => {
    'section': section,
    'label': label,
    'value': value,
    'unit': unit,
    'period': period,
    'breakdown': bars,
    'source_name': 'بيانات تجريبية',
    'source_url': '$_site/$source/data',
  };
  return switch (institutionId) {
    oasis => [
      stat('people', 'عدد الطلاب', 18400, null, '2026', [
        {'label': 'بكالوريوس', 'value': 15200},
        {'label': 'دراسات عليا', 'value': 3200},
      ]),
      stat('study', 'نسبة التخرج في المدة المحددة', 71.5, '%', '2025'),
      stat('digital', 'تقييم تطبيق الواحة (تجريبي)', 3.8, '/5', 'App Store', [
        {'label': 'عدد التقييمات', 'value': 1250},
      ]),
    ],
    _ => [
      stat('people', 'عدد المتدربين', 4200, null, '2026'),
      stat('digital', 'تقييم تطبيق النخلة (تجريبي)', 4.1, '/5', 'App Store', [
        {'label': 'عدد التقييمات', 'value': 310},
      ]),
    ],
  };
}

List<Row> infoSections(int institutionId) {
  Row section(String kind, int position, int asked, [String? note]) => {
    'kind': kind,
    'position': position,
    'asked': asked,
    'note': note,
    'checked_at': _ago(const Duration(minutes: 20)),
  };
  return switch (institutionId) {
    oasis => [
      section('status', 1, 12),
      section('dates', 2, 6, 'مواعيد الفصل الأول في التقويم التجريبي.'),
      section('help', 3, 4),
      section('apps', 4, 2),
      section('numbers', 5, 0),
    ],
    _ => [
      section('dates', 1, 5),
      section('status', 2, 3),
      section('help', 3, 2),
      section('apps', 4, 0),
      section('numbers', 5, 0),
    ],
  };
}

List<Row> infoItems(int institutionId) {
  final source = institutionId == oasis ? 'oasis' : 'palm';
  final name = institutionId == oasis
      ? 'جامعة الواحة (تجريبية)'
      : 'كلية النخلة التقنية (تجريبية)';
  Row date(String title, int start, [int? end]) => {
    'kind': 'dates',
    'title': title,
    'starts_on': _day(start),
    'ends_on': end == null ? null : _day(end),
    'source_name': '$name - التقويم',
    'source_url': '$_site/$source/calendar',
  };
  Row help(String title, String link, [String? detail]) => {
    'kind': 'help',
    'title': title,
    'detail': detail,
    'link': link,
    'source_name': '$name - تواصل معنا',
    'source_url': '$_site/$source/contact',
  };
  return switch (institutionId) {
    oasis => [
      {
        'kind': 'status',
        'title': 'جامعة الواحة: الدراسة عن بعد يوم الأحد بسبب التقلبات الجوية (مثال)',
        'published_at': _ago(const Duration(hours: 3)),
        'link': '$_site/oasis/news/101',
        'source_name': 'جامعة الواحة (تجريبية)',
        'source_url': '$_site/oasis/news/101',
      },
      date('بداية الاختبارات الفصلية', 5),
      date('إجازة منتصف الفصل', 18, 22),
      date('آخر يوم للانسحاب من مقرر', 30),
      date('الاختبارات النهائية', 52, 63),
      date('بداية الفصل الثاني', 80),
      help(
        'خدمة الطلاب الإلكترونية',
        '$_site/oasis/help',
        'تفتح تذكرة ويرد عليها الموظف خلال يومي عمل.',
      ),
      help('بريد القبول والتسجيل', 'mailto:help@example.com'),
    ],
    _ => [
      date('آخر موعد للحذف والإضافة', 2),
      date('الاختبارات النهائية', 45, 52),
      help(
        'مكتب شؤون المتدربين',
        '$_site/palm/help',
        'يرد على الأسئلة في أيام الدوام.',
      ),
    ],
  };
}

List<Row> sources(int institutionId) {
  final source = institutionId == oasis ? 'oasis' : 'palm';
  final name = institutionId == oasis ? 'جامعة الواحة' : 'كلية النخلة التقنية';
  Row channel(
    String what,
    String platform,
    String role,
    String status,
    String path, [
    String? note,
  ]) => {
    'name': '$name: $what',
    'platform': platform,
    'role': role,
    'status': status,
    'url': '$_site/$source/$path',
    'handle': null,
    'note': note,
  };
  return [
    channel('الحساب الرسمي', 'x', 'news', 'collected', 'x'),
    channel('الموقع', 'website', 'news', 'collected', 'news'),
    channel(
      'قناة يوتيوب',
      'youtube',
      'news',
      'planned',
      'youtube',
      'تُجمع عند إضافة مفتاح يوتيوب (مثال).',
    ),
    channel('الردود على الحساب الرسمي', 'x', 'opinions', 'collected', 'x'),
    channel('التطبيق في App Store', 'app_store', 'stats', 'collected', 'app'),
  ];
}
