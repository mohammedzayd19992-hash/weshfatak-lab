import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uninews/models.dart';
import 'package:uninews/widgets/info.dart';

final _now = DateTime(2026, 11, 4, 15, 0);

InfoItem _date(String title, String start, [String? end]) => InfoItem.fromMap({
  'kind': 'dates',
  'title': title,
  'starts_on': start,
  'ends_on': end,
  'source_name': 'سبق',
  'source_url': 'https://sabq.org/article/raleyvc',
});

Widget _page(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  test('The Info page follows what people asked, with the numbers last', () {
    final page = InfoPage(
      sections: [
        InfoSection.fromMap({'kind': 'numbers', 'position': 1, 'asked': 0}),
        InfoSection.fromMap({'kind': 'help', 'position': 2, 'asked': 7}),
        InfoSection.fromMap({
          'kind': 'status',
          'position': 1,
          'asked': 18,
          'checked_at': '2026-11-04T09:30:00+00:00',
        }),
      ],
    );
    expect(page.ranked, isTrue);
    expect(page.order, ['status', 'help', 'dates', 'apps', 'numbers']);
    expect(
      page.section('status')!.checkedAt!.toUtc(),
      DateTime.utc(2026, 11, 4, 9, 30),
    );
    expect(const InfoPage().order, infoKinds);
    expect(const InfoPage().ranked, isFalse);
  });

  test('A date row reads its days without a time zone', () {
    final item = _date('إجازة الخريف', '2026-11-22', '2026-11-26');
    expect(item.startsOn, DateTime(2026, 11, 22));
    expect(item.lastDay, DateTime(2026, 11, 26));
    expect(
      _date('بداية الاختبارات', '2026-12-20').lastDay,
      DateTime(2026, 12, 20),
    );
  });

  test('Countdowns, ranges and times in English', () {
    expect(daysBetween(_now, DateTime(2026, 11, 22)), 18);
    expect(
      countdown(_date('a', '2026-11-22', '2026-11-26'), now: _now),
      'In 18 days',
    );
    expect(countdown(_date('a', '2026-11-05'), now: _now), 'Tomorrow');
    expect(countdown(_date('a', '2026-11-04'), now: _now), 'Today');
    expect(countdown(_date('a', '2026-11-01', '2026-11-05'), now: _now), 'Now');
    expect(
      dateRange(_date('a', '2026-11-22', '2026-11-26'), now: _now),
      'Sun Nov 22 – Thu Nov 26',
    );
    expect(dateRange(_date('a', '2027-01-07'), now: _now), 'Thu Jan 7, 2027');
    expect(
      timeAgo(_now.subtract(const Duration(minutes: 5)), now: _now),
      '5 min ago',
    );
    expect(
      timeAgo(_now.subtract(const Duration(hours: 3)), now: _now),
      '3 h ago',
    );
    expect(
      timeAgo(_now.subtract(const Duration(days: 2)), now: _now),
      '2 days ago',
    );
    expect(clock(DateTime(2026, 11, 4, 9, 5), now: _now), '09:05');
    expect(clock(DateTime(2026, 11, 2, 21, 30), now: _now), 'Nov 2 21:30');
  });

  test('Only dates that have not ended, soonest first', () {
    final dates = upcomingDates([
      _date('later', '2026-12-20'),
      _date('over', '2026-11-01', '2026-11-03'),
      _date('going on', '2026-11-01', '2026-11-05'),
    ], now: _now);
    expect(dates.map((item) => item.title), ['going on', 'later']);
  });

  test('Channels show their number, address or site', () {
    expect(linkLabel('tel:19996'), '19996');
    expect(linkLabel('mailto:info@su.edu.sa'), 'info@su.edu.sa');
    expect(linkLabel('https://tawasul.moe.gov.sa/'), 'tawasul.moe.gov.sa');
    expect(linkIcon('tel:19996'), Icons.call_rounded);
  });

  testWidgets('Arabic counts use the right word for each number', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('ar');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    expect(countdown(_date('a', '2026-11-06'), now: _now), 'بعد يومين');
    expect(countdown(_date('a', '2026-11-09'), now: _now), 'بعد 5 أيام');
    expect(countdown(_date('a', '2026-11-22'), now: _now), 'بعد 18 يومًا');
    expect(countdown(_date('a', '2026-11-05'), now: _now), 'غدًا');
    expect(
      timeAgo(_now.subtract(const Duration(hours: 1)), now: _now),
      'قبل ساعة',
    );
    expect(
      timeAgo(_now.subtract(const Duration(hours: 2)), now: _now),
      'قبل ساعتين',
    );
    expect(
      timeAgo(_now.subtract(const Duration(hours: 13)), now: _now),
      'قبل 13 ساعة',
    );
    expect(
      dateRange(_date('a', '2026-11-20', '2026-11-28'), now: _now),
      'الجمعة 20/11 – السبت 28/11',
    );
  });

  testWidgets('With no announcement, the study card says so plainly', (
    tester,
  ) async {
    await tester.pumpWidget(
      _page(
        StudyStatus(
          items: const [],
          section: InfoSection(
            kind: 'status',
            position: 1,
            checkedAt: DateTime(2026, 11, 4, 14, 5),
          ),
          now: _now,
        ),
      ),
    );
    expect(
      find.textContaining('No announcement in the last 7 days'),
      findsOneWidget,
    );
    expect(find.text('Checked 14:05'), findsOneWidget);
  });

  testWidgets('Study announcements show their source and how long ago', (
    tester,
  ) async {
    await tester.pumpWidget(
      _page(
        StudyStatus(
          items: [
            InfoItem.fromMap({
              'kind': 'status',
              'title': 'تعليم الرياض يعلن تعليق الدراسة الحضورية حتى الخميس',
              'published_at': '2026-11-04T09:00:00+03:00',
              'link': 'https://news.google.com/rss/articles/A',
              'source_name': 'صدى',
              'source_url': 'https://news.google.com/rss/articles/A',
            }),
          ],
          now: DateTime.parse('2026-11-04T12:00:00+03:00').toLocal(),
        ),
      ),
    );
    expect(
      find.text('تعليم الرياض يعلن تعليق الدراسة الحضورية حتى الخميس'),
      findsOneWidget,
    );
    expect(find.text('صدى · 3 h ago'), findsOneWidget);
    expect(find.textContaining('No announcement'), findsNothing);
  });

  testWidgets('Coming up shows the next four dates, then all of them', (
    tester,
  ) async {
    final dates = [
      for (var day = 10; day <= 15; day++) _date('موعد $day', '2026-11-$day'),
    ];
    await tester.pumpWidget(_page(ComingUp(items: dates, now: _now)));
    expect(find.textContaining('موعد'), findsNWidgets(4));
    expect(find.text('In 6 days'), findsOneWidget);
    await tester.tap(find.text('All 6 dates'));
    await tester.pump();
    expect(find.textContaining('موعد'), findsNWidgets(6));
    expect(find.text('Source: سبق'), findsOneWidget);
  });

  testWidgets('Where to ask shows each channel and its source once', (
    tester,
  ) async {
    await tester.pumpWidget(
      _page(
        WhereToAsk(
          items: [
            for (final link in ['https://tawasul.moe.gov.sa/', 'tel:19996'])
              InfoItem.fromMap({
                'kind': 'help',
                'title': link,
                'link': link,
                'source_name': 'وزارة التعليم - خدمة تواصل',
                'source_url':
                    'https://www.moe.gov.sa/ar/contactus/pages/tawasul.aspx',
              }),
          ],
        ),
      ),
    );
    expect(find.text('19996'), findsOneWidget);
    expect(find.text('tawasul.moe.gov.sa'), findsOneWidget);
    expect(find.text('Source: وزارة التعليم - خدمة تواصل'), findsOneWidget);
  });
}
