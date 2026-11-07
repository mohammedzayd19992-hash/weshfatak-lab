import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uninews/data.dart';
import 'package:uninews/demo.dart' as demo;
import 'package:uninews/format.dart';
import 'package:uninews/models.dart';
import 'package:uninews/widgets/mood.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    UniNewsApi.keepOn(await SharedPreferences.getInstance());
    UniNewsApi.demoForTests = false;
    UniNewsApi.offlineSince.value = null;
  });
  tearDown(() => UniNewsApi.demoForTests = null);

  test('Without a connection a page shows what it showed last time, and says since when', () async {
    final first = await UniNewsApi.rowsForTests(
      'feed.1',
      () async => [
        {'news_id': 1, 'body': 'خبر'},
      ],
    );
    expect(first.single['body'], 'خبر');
    expect(UniNewsApi.offlineSince.value, isNull);
    await Future<void>.delayed(
      Duration.zero,
    ); // the rows are kept in the background

    final offline = await UniNewsApi.rowsForTests(
      'feed.1',
      () async => throw const SocketException('no connection'),
    );
    expect(offline.single['body'], 'خبر');
    expect(UniNewsApi.offlineSince.value, isNotNull);

    // A page never loaded before has nothing to show: the error reaches the page as before.
    await expectLater(
      UniNewsApi.rowsForTests(
        'feed.2',
        () async => throw const SocketException('no connection'),
      ),
      throwsA(isA<SocketException>()),
    );

    // Back online, the line goes away.
    await UniNewsApi.rowsForTests(
      'feed.1',
      () async => [
        {'news_id': 1, 'body': 'جديد'},
      ],
    );
    expect(UniNewsApi.offlineSince.value, isNull);
  });

  test('Only the 20 most recently opened stories are kept', () async {
    final prefs = await SharedPreferences.getInstance();
    for (var id = 1; id <= 25; id++) {
      await prefs.setString('weshfatak.kept.v1.post.$id', '{}');
      await UniNewsApi.rememberForTests(id);
    }
    expect(prefs.getString('weshfatak.kept.v1.post.25'), isNotNull);
    expect(prefs.getString('weshfatak.kept.v1.post.6'), isNotNull);
    expect(prefs.getString('weshfatak.kept.v1.post.5'), isNull);
    expect(prefs.getStringList('weshfatak.kept.v1.posts'), hasLength(20));
  });

  test(
    'The app opens web pages, numbers and email addresses, nothing else',
    () {
      expect(canOpen('https://www.moe.gov.sa/'), isTrue);
      expect(canOpen('tel:19996'), isTrue);
      expect(canOpen('mailto:info@su.edu.sa'), isTrue);
      expect(canOpen('intent://scan/#Intent;scheme=zxing;end'), isFalse);
      expect(canOpen('javascript:alert(1)'), isFalse);
      expect(canOpen('file:///sdcard/a.txt'), isFalse);
      expect(canOpen('www.example.com'), isFalse);
    },
  );

  test('Every demo row reads like a database row', () {
    final institutions = demo.institutions().map(Institution.fromMap).toList();
    expect(institutions.map((i) => i.id), [demo.oasis, demo.palm]);
    for (final institution in institutions) {
      final posts = demo
          .feed(institution.id, 0, 10)
          .map(NewsPost.fromMap)
          .toList();
      expect(institution.postCount, posts.length);
      for (final post in posts) {
        expect(
          demo.replies(post.id).map(PublicReply.fromMap),
          hasLength(post.replyCount),
        );
        expect(totalOf(post.emotions), post.replyCount);
      }
      demo.stats(institution.id).forEach(InstitutionStat.fromMap);
      demo.reviews(institution.id).forEach(AppReview.fromMap);
      demo.sources(institution.id).forEach(NewsSource.fromMap);
      final page = InfoPage(
        sections: demo
            .infoSections(institution.id)
            .map(InfoSection.fromMap)
            .toList(),
        items: demo.infoItems(institution.id).map(InfoItem.fromMap).toList(),
      );
      expect(page.order.last, 'numbers');
      // Every link in the demo goes to example.com, which belongs to no one.
      for (final item in page.items) {
        expect(
          '${item.link ?? ''} ${item.sourceUrl}',
          isNot(contains(RegExp(r'https://(?!example\.com)'))),
        );
      }
    }
  });

  test('Moods are spoken without emoji', () {
    expect(
      moodSpoken({'happy': 13, 'angry': 38, 'asking': 9}),
      '63% Angry, 22% Happy',
    );
    expect(moodSpoken({}), '');
  });
}
