// The prototype: the line that says how old the data is, the About page's words, the feedback link
// and the version it shows.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uninews/config.dart';
import 'package:uninews/data.dart';
import 'package:uninews/format.dart';
import 'package:uninews/widgets/info.dart';
import 'package:uninews/widgets/prototype.dart';

final _now = DateTime(2026, 11, 7, 10, 0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    UniNewsApi.demoForTests = null;
    UniNewsApi.collectedAt.value = null;
  });

  test(
    'Data a day old counts as old: the collectors run every 2.5 hours when on',
    () {
      expect(dataIsOld(null, now: _now), isFalse);
      expect(
        dataIsOld(_now.subtract(const Duration(hours: 23)), now: _now),
        isFalse,
      );
      expect(
        dataIsOld(_now.subtract(const Duration(hours: 25)), now: _now),
        isTrue,
      );
    },
  );

  test('The prototype line says how old the data is', () {
    expect(prototypeLine(null, now: _now), 'Prototype');
    expect(
      prototypeLine(_now.subtract(const Duration(hours: 3)), now: _now),
      'Prototype · updated 3 h ago',
    );
    expect(
      prototypeLine(DateTime(2026, 11, 4, 20, 32), now: _now),
      'Prototype · data up to Wed Nov 4',
    );
  });

  test(
    'The About page says whether the data is made up, paused or current',
    () {
      expect(collectionLine(null, demo: true, now: _now), contains('made-up'));
      expect(collectionLine(null, demo: false, now: _now), isNull);
      expect(
        collectionLine(DateTime(2026, 11, 4, 20, 32), demo: false, now: _now),
        'Collection is paused for now, so the news, replies and study status stop at Wed Nov 4.',
      );
      expect(
        collectionLine(
          _now.subtract(const Duration(hours: 2)),
          demo: false,
          now: _now,
        ),
        'Collected automatically every few hours, last 2 h ago.',
      );
    },
  );

  testWidgets('The prototype line in Arabic', (tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('ar');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    expect(
      prototypeLine(DateTime(2026, 11, 4, 20, 32), now: _now),
      'نموذج أولي · البيانات حتى الأربعاء 4/11',
    );
    expect(
      prototypeLine(_now.subtract(const Duration(hours: 2)), now: _now),
      'نموذج أولي · حُدّث قبل ساعتين',
    );
  });

  testWidgets(
    'The home screen line follows the data date and opens the About page',
    (tester) async {
      UniNewsApi.demoForTests = false;
      UniNewsApi.collectedAt.value = DateTime.now().subtract(
        const Duration(days: 3),
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PrototypeNote())),
      );
      expect(find.textContaining('Prototype · data up to'), findsOneWidget);
      UniNewsApi.collectedAt.value = DateTime.now().subtract(
        const Duration(minutes: 30),
      );
      await tester.pump();
      expect(find.text('Prototype · updated 30 min ago'), findsOneWidget);
      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();
      expect(find.text('A prototype'), findsOneWidget);
      expect(find.textContaining('Collected automatically'), findsOneWidget);
      expect(find.textContaining('not an official service'), findsOneWidget);
    },
  );

  test('The data date is the newest post or Info check', () async {
    String kept(List<Map<String, dynamic>> rows) => jsonEncode({
      'at': DateTime.utc(2026, 11, 7).toIso8601String(),
      'rows': rows,
    });
    // No Supabase in tests: every question fails, so the app reads what the phone kept.
    SharedPreferences.setMockInitialValues({
      'weshfatak.kept.v1.institutions': kept([
        {
          'organization_id': 31,
          'name': 'Ministry',
          'last_post_at': '2026-11-04T09:00:42+00:00',
        },
        {
          'organization_id': 36,
          'name': 'Shaqra',
          'last_post_at': '2026-11-01T12:44:25+00:00',
        },
      ]),
      'weshfatak.kept.v1.last_info_check': kept([
        {'checked_at': '2026-11-04T17:32:22+00:00'},
      ]),
    });
    UniNewsApi.keepOn(await SharedPreferences.getInstance());
    UniNewsApi.demoForTests = false;
    expect(await UniNewsApi.institutions(), hasLength(2));
    expect(
      UniNewsApi.collectedAt.value!.toUtc(),
      DateTime.utc(2026, 11, 4, 17, 32, 22),
    );

    // The demo has no data date: its line just says "Prototype".
    UniNewsApi.collectedAt.value = null;
    UniNewsApi.demoForTests = true;
    await UniNewsApi.institutions();
    expect(UniNewsApi.collectedAt.value, isNull);
  });

  test(
    'Feedback fills in the GitHub form, and leaves any other page as it is',
    () {
      final link = Uri.parse(
        feedbackLink(
          title: 'Mistake: story 7',
          body: 'Story: https://x.com/a/status/1',
        ),
      );
      expect(link.host, 'github.com');
      expect(link.path, endsWith('/weshfatak-lab/issues/new'));
      expect(link.queryParameters['title'], 'Mistake: story 7');
      expect(link.queryParameters['body'], 'Story: https://x.com/a/status/1');
      expect(canOpen(link.toString()), isTrue);
      const form = 'https://forms.example.com/weshfatak';
      expect(feedbackLink(title: 'a', body: 'b', page: form), form);
      expect(canOpen(sourceCodeUrl), isTrue);
    },
  );

  test('The About page shows the version in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([\d.]+)\+',
      multiLine: true,
    ).firstMatch(pubspec)!;
    expect(appVersion, version.group(1));
    expect(isPrototype, isTrue);
  });
}
