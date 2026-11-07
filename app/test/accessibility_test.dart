// The whole app, in the demo (no database), at double text size on a small phone, in English and
// Arabic: every page must lay out without overflowing and pass Flutter's accessibility checks
// (touch targets of at least 48 by 48, a label on everything tappable, readable text contrast).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uninews/app_state.dart';
import 'package:uninews/data.dart';
import 'package:uninews/main.dart';

Future<void> _openApp(
  WidgetTester tester, {
  required String language,
  double textScale = 2,
}) async {
  tester.view.physicalSize = const Size(360 * 3, 740 * 3);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.localeTestValue = Locale(language);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  UniNewsApi.keepOn(prefs);
  await tester.pumpWidget(
    AppScope(state: AppState(prefs), child: const UniNewsApp()),
  );
  await tester.pumpAndSettle();
}

Future<void> _meetsGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

/// The list that holds [anchor], found once so it stays found after [anchor] scrolls away.
Finder _listOf(WidgetTester tester, Finder anchor) {
  final list = tester.element(
    find.ancestor(of: anchor, matching: find.byType(Scrollable)).first,
  );
  return find.byElementPredicate((element) => element == list);
}

/// Scrolls [list] until [target] is on screen, then checks the guidelines there.
Future<void> _scrollTo(
  WidgetTester tester,
  Finder target, {
  required Finder list,
  double step = 250,
}) async {
  await tester.scrollUntilVisible(target, step, scrollable: list);
  await tester.pumpAndSettle();
  await _meetsGuidelines(tester);
}

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets('Every page works at double text size ($language)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _openApp(tester, language: language);
      final arabic = language == 'ar';
      String say(String en, String ar) => arabic ? ar : en;

      // Home: the demo says it is the demo, and the prototype line opens the About page.
      expect(find.textContaining(say('Demo:', 'نسخة تجريبية')), findsOneWidget);
      await _meetsGuidelines(tester);
      // (The test font draws every letter a full square wide, so the line starts below the screen.)
      final prototype = find.text(say('Prototype', 'نموذج أولي'));
      await tester.ensureVisible(prototype);
      await tester.pumpAndSettle();
      await _meetsGuidelines(tester);
      await tester.tap(prototype);
      await tester.pumpAndSettle();
      final about = _listOf(tester, find.text(say('What it is', 'ما هو')));
      await _meetsGuidelines(tester);
      await _scrollTo(
        tester,
        find.textContaining(say('shows made-up', 'تعرض جهات')),
        list: about,
      );
      await _scrollTo(
        tester,
        find.text(say('Source code on GitHub', 'الشفرة المصدرية على GitHub')),
        list: about,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // An institution's news (with double text the first card starts below the screen).
      final card = find
          .text(
            say('Oasis University (demo)', 'جامعة الواحة (تجريبية)'),
            skipOffstage: false,
          )
          .first;
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await _meetsGuidelines(tester);
      await tester.tap(card);
      await tester.pumpAndSettle();
      final story = find.textContaining('تحويل الدراسة يوم الأحد');
      expect(story, findsOneWidget);
      await _meetsGuidelines(tester);
      final news = _listOf(tester, story);
      await _scrollTo(tester, find.textContaining('مركزًا للبحث'), list: news);

      // Its Info page: study first (most asked in the demo), then the coming dates, where to ask.
      await tester.tap(find.text(say('Info', 'المعلومات')));
      await tester.pumpAndSettle();
      final info = _listOf(tester, find.textContaining('جامعة من الخيال'));
      await _meetsGuidelines(tester);
      await _scrollTo(
        tester,
        find.text(
          say('Study: in person or online?', 'الدراسة: حضوري أم عن بعد؟'),
        ),
        list: info,
      );
      await _scrollTo(
        tester,
        find.text(say('Coming up', 'المواعيد القادمة')),
        list: info,
      );
      await _scrollTo(
        tester,
        find.text(say('Where to ask', 'أين تسأل؟')),
        list: info,
      );
      await _scrollTo(tester, find.text(say('Numbers', 'أرقام')), list: info);

      // Its Sources, down to its apps.
      await tester.tap(find.text(say('Sources', 'المصادر')));
      await tester.pumpAndSettle();
      await _meetsGuidelines(tester);
      final sources = _listOf(
        tester,
        find.textContaining(
          say('Every official channel', 'كل القنوات الرسمية'),
        ),
      );
      await _scrollTo(
        tester,
        find.textContaining('جامعة الواحة: الحساب الرسمي'),
        list: sources,
      );
      await _scrollTo(
        tester,
        find.textContaining('التطبيق في App Store'),
        list: sources,
      );

      // A story with its replies; picking a face shows only its replies.
      await tester.tap(find.text(say('News', 'الأخبار')));
      await tester.pumpAndSettle();
      // Back up the list; with double text the story is taller than the screen, so tap its top.
      // (Only in this list: the home page underneath shows the same headline.)
      final storyAnywhere = find.descendant(
        of: news,
        matching: find.textContaining('تحويل الدراسة يوم الأحد'),
        skipOffstage: false,
      );
      await tester.scrollUntilVisible(storyAnywhere, -250, scrollable: news);
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getTopLeft(storyAnywhere) + const Offset(24, 12),
      );
      await tester.pumpAndSettle();
      await _meetsGuidelines(tester);
      final page = _listOf(tester, story.first);
      final worried = find.text(say('Worried', 'قلق'));
      await _scrollTo(tester, worried, list: page);
      await tester.tap(worried.first);
      await tester.pumpAndSettle();
      // Under the AI's summary, the way to report a mistake in it.
      await _scrollTo(
        tester,
        find.text(say('Report a mistake', 'الإبلاغ عن خطأ')),
        list: page,
      );
      await _scrollTo(
        tester,
        find.text(say('Replies on X', 'الردود على إكس')),
        list: page,
      );
      await _scrollTo(
        tester,
        find.textContaining('الإنترنت في السكن'),
        list: page,
      );
      expect(
        find.textContaining('الله يجزاكم خير', skipOffstage: false),
        findsNothing,
      );

      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  }

  testWidgets('A card is one item, and faces are read by name, not by emoji', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openApp(tester, language: 'en', textScale: 1);
    expect(
      find.semantics.byLabel(
        RegExp(r'^Oasis University \(demo\)\n[\s\S]*3 posts\n8 replies'),
      ),
      findsOne,
    );
    expect(find.semantics.byLabel(RegExp('Replies: 38% Asking')), findsOne);
    expect(find.semantics.byLabel(RegExp('🤔')), findsNothing);
    handle.dispose();
  });
}
