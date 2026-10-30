import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uninews/app_name.dart';
import 'package:uninews/models.dart';
import 'package:uninews/news_alerts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          NewsAlerts.channel,
          (call) async => call.method == 'sync' ? null : true,
        );
  });
  test('app name follows Arabic and English phone locales', () {
    expect(appNameFor(const Locale('ar', 'SA')), 'وش فاتك');
    expect(appNameFor(const Locale('en', 'GB')), 'WeshFatak');
    expect(appNameFor(const Locale('fr')), 'WeshFatak');
  });
  test(
    'independent alert filters and disabled state survive a restart',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final alerts = NewsAlerts(prefs);
      final selectedAudiences = {'Students'};
      await alerts.add(
        FeedFilters(audiences: selectedAudiences),
        importantOnly: true,
      );
      selectedAudiences.add('Teaching Staff');
      await alerts.add(
        const FeedFilters(
          audiences: {'Administrative Staff'},
          categories: {'Exams'},
        ),
        importantOnly: false,
      );
      final firstId = alerts.saved.first.id;
      await alerts.toggle(firstId, false);
      final restarted = NewsAlerts(prefs);
      expect(restarted.saved, hasLength(2));
      expect(restarted.saved.first.filters.audiences, {'Students'});
      expect(restarted.saved.first.enabled, false);
      expect(restarted.saved.last.filters.audiences, {'Administrative Staff'});
      expect(restarted.saved.last.importantOnly, false);
      await restarted.remove(firstId);
      expect(NewsAlerts(prefs).saved.single.filters.categories, {'Exams'});
    },
  );
  test(
    'reordered selections cannot create duplicate alert subscriptions',
    () async {
      final alerts = NewsAlerts(await SharedPreferences.getInstance());
      await alerts.add(
        const FeedFilters(categories: {'Exams', 'Academic'}),
        importantOnly: true,
      );
      await expectLater(
        alerts.add(
          const FeedFilters(categories: {'Academic', 'Exams'}),
          importantOnly: true,
        ),
        throwsStateError,
      );
      expect(alerts.saved, hasLength(1));
    },
  );
}
