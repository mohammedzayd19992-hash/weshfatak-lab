import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uninews/format.dart';
import 'package:uninews/models.dart';
import 'package:uninews/widgets/mood.dart';
import 'package:uninews/widgets/post_card.dart';
import 'package:uninews/widgets/stats.dart';

const _minimal = {
  'news_id': 1,
  'body': 'خبر',
  'published_at': '2026-10-13T12:00:00+00:00',
  'source_url': 'https://www.su.edu.sa/ar/news/1',
  'source_name': 'جامعة شقراء',
  'organization': 'Shaqra University',
};

void main() {
  test('NewsPost reads a news_cards row with its institution and mood', () {
    final post = NewsPost.fromMap({
      'news_id': 2,
      'body': 'On the occasion of #WorldMentalHealthDay',
      'published_at': '2026-10-13T12:00:00+00:00',
      'source_url': 'https://x.com/ShaqraUni#preview-2',
      'source_name': 'جامعة شقراء',
      'source_type': 'social',
      'platform': 'x',
      'handle': '@ShaqraUni',
      'avatar_url': null,
      'organization': 'Shaqra University',
      'organization_id': 36,
      'media': [
        {
          'url': 'https://example.com/a.png',
          'alt': 'Photos',
          'width': 480,
          'height': 317,
        },
      ],
      'reply_count': 3,
      'emotions': {'happy': 2, 'angry': 1},
    });

    expect(post.id, 2);
    expect(post.organizationId, 36);
    expect(post.platform, 'x');
    expect(post.emotions, {'happy': 2, 'angry': 1});
    expect(post.media.single.aspectRatio, closeTo(1.514, 0.001));
    expect(post.sourceLink, 'https://x.com/ShaqraUni');
    expect(post.publishedAt.toUtc(), DateTime.utc(2026, 10, 13, 12));
  });

  test('A press report reads the other sources of its story', () {
    final post = NewsPost.fromMap({
      'news_id': 189,
      'body': 'وزير التعليم يبحث تعزيز الشراكة السعودية التركية',
      'published_at': '2026-10-27T19:18:46+00:00',
      'source_url': 'https://news.google.com/rss/articles/A1?oc=5',
      'source_name': 'واس',
      'source_type': 'press',
      'platform': 'media',
      'organization': 'Ministry of Education',
      'also_in': [
        {
          'source_name': 'وزارة التعليم',
          'platform': 'x',
          'source_type': 'social',
          'url': 'https://x.com/moe_gov_sa/status/2115161300363829265',
        },
        {
          'source_name': 'عكاظ',
          'platform': 'media',
          'source_type': 'press',
          'url': 'https://news.google.com/rss/articles/A2?oc=5',
        },
      ],
    });

    expect(post.isPress, isTrue);
    expect(post.alsoIn, hasLength(2));
    expect(post.alsoIn.first.isPress, isFalse);
    expect(AlsoReported.labelOf(post.alsoIn.last), 'عكاظ');
    expect(AlsoReported.labelOf(post.alsoIn.first), 'X');
    expect(NewsPost.fromMap(_minimal).alsoIn, isEmpty);
    expect(NewsPost.fromMap(_minimal).isPress, isFalse);
  });

  testWidgets('Also reported by names each source once', (tester) async {
    StoryCopy copy(String name, String platform, String type) => StoryCopy(
      sourceName: name,
      url: 'https://example.com/$name',
      platform: platform,
      sourceType: type,
    );
    final copies = [
      copy('وزارة التعليم', 'youtube', 'social'),
      copy('وزارة التعليم', 'youtube', 'social'),
      copy('المركز الإعلامي', 'website', 'website'),
      copy('واس', 'media', 'press'),
      copy('سبق', 'media', 'press'),
      copy('عاجل', 'media', 'press'),
    ];
    Future<void> show({required bool detail}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: AlsoReported(copies: copies, detail: detail),
          ),
        ),
      ),
    );

    await show(detail: false);
    expect(find.text('Also reported by'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('Website'), findsOneWidget);
    expect(find.text('عاجل'), findsNothing);
    expect(find.text('+1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await show(detail: true);
    expect(find.text('عاجل'), findsOneWidget);
    expect(find.text('+1'), findsNothing);
  });

  test('An institution reads its newest post and numbers sent as text', () {
    final institution = Institution.fromMap({
      'organization_id': 31,
      'name': 'Ministry of Education',
      'name_ar': 'وزارة التعليم',
      'kind': 'ministry',
      'post_count': 5,
      'last_post_at': '2026-10-25T10:10:30+00:00',
      'latest_body': 'الكشف المبكر يرفع فرص الشفاء.',
      'reply_count': 20,
      'review_count': 48,
      'review_rating': '1.77',
      'emotions': {'happy': 10, 'asking': 7, 'angry': 3},
    });

    expect(institution.latestBody, 'الكشف المبكر يرفع فرص الشفاء.');
    expect(
      institution.lastPostAt!.toUtc(),
      DateTime.utc(2026, 10, 25, 10, 10, 30),
    );
    expect(totalOf(institution.emotions), institution.replyCount);
    expect(institution.reviewRating, 1.77);
    expect(
      Institution.fromMap({'organization_id': 1, 'name': 'X'}).latestBody,
      isNull,
    );
  });

  test('A statistic keeps its bars, period and source', () {
    final stat = InstitutionStat.fromMap({
      'section': 'study',
      'label': 'المقبولون الجدد في البكالوريوس',
      'value': 3575,
      'unit': null,
      'period': '1445هـ',
      'breakdown': [
        {'label': 'كلية العلوم والدراسات الإنسانية بالدوادمي', 'value': 1229},
      ],
      'source_name': 'البيانات المفتوحة - جامعة شقراء',
      'source_url': 'https://opendata.su.edu.sa/api/BachelorAdmittedStudentsByCollege/1445',
    });

    expect(stat.value, 3575);
    expect(stat.breakdown.single.value, 1229);
    expect(statValue(stat.value, stat.unit), '3,575');
    expect(statValue(83.88, '%'), '83.88%');
    expect(statValue(2.96, '/5'), '2.96 / 5');
  });

  test('The mood headline names the two most common faces', () {
    expect(
      moodHeadline({'happy': 13, 'angry': 38, 'asking': 9}),
      '😠 63% Angry  ·  😄 22% Happy',
    );
    expect(moodHeadline({}), '');
    expect(percent(1, 3), 33);
    expect(faceFor('sarcastic')!.emoji, '🙃');
    expect(faceFor('nonsense'), isNull);
  });

  testWidgets('The face rows fit a narrow phone and pick a face', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: MoodBars(
                counts: const {'happy': 4, 'angry': 2, 'asking': 1},
                onSelect: (face) => picked = face,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Angry'), findsOneWidget);
    expect(find.text('Sad'), findsNothing);
    expect(find.textContaining('Only 7 replies'), findsOneWidget);
    await tester.tap(find.text('Angry'));
    expect(picked, 'angry');
    expect(tester.takeException(), isNull);
  });

  test('Arabic text is laid out right to left', () {
    expect(directionOf('جامعة شقراء'), TextDirection.rtl);
    expect(directionOf('2026 جامعة شقراء'), TextDirection.rtl);
    expect(
      directionOf('#ShaqraUniversity held a health event'),
      TextDirection.ltr,
    );
  });

  test('Dates show the year only for older posts', () {
    final now = DateTime(2026, 10, 18);
    expect(shortDate(DateTime(2026, 10, 15), now: now), 'Oct 15');
    expect(shortDate(DateTime(2025, 3, 2), now: now), 'Mar 2, 2025');
  });
}
