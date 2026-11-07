import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uninews/app_name.dart';
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
  test('followed institutions and paused alerts survive a restart', () async {
    final prefs = await SharedPreferences.getInstance();
    final alerts = NewsAlerts(prefs);
    await alerts.follow(31, 'وزارة التعليم');
    await alerts.follow(36, 'جامعة شقراء');
    await alerts.toggle(alerts.alertFor(31)!.id, false);

    final restarted = NewsAlerts(prefs);
    expect(restarted.saved, hasLength(2));
    expect(restarted.follows(31), isFalse);
    expect(restarted.follows(36), isTrue);
    expect(restarted.alertFor(36)!.name, 'جامعة شقراء');

    await restarted.remove(restarted.alertFor(36)!.id);
    expect(NewsAlerts(prefs).saved.single.organizationId, 31);
  });
  test(
    'following again resumes the same alert instead of adding one',
    () async {
      final alerts = NewsAlerts(await SharedPreferences.getInstance());
      await alerts.follow(36, 'Shaqra University');
      final first = alerts.alertFor(36)!;
      await alerts.toggle(first.id, false);
      await alerts.follow(36, 'Shaqra University');
      expect(alerts.saved, hasLength(1));
      expect(alerts.follows(36), isTrue);
      // Resuming starts a new window, so posts collected while paused are not announced.
      expect(
        alerts.alertFor(36)!.since.compareTo(first.since),
        greaterThanOrEqualTo(0),
      );
    },
  );
  test(
    'alerts saved by the filter version are not mistaken for follows',
    () async {
      SharedPreferences.setMockInitialValues({
        'weshfatak.alerts.v1': '[{"id":"1","filters":{"audiences":["Students"]},"since":"2026-10-19T00:00:00Z"}]',
      });
      expect(NewsAlerts(await SharedPreferences.getInstance()).saved, isEmpty);
    },
  );
  test('at most ten institutions can be followed', () async {
    final alerts = NewsAlerts(await SharedPreferences.getInstance());
    for (var id = 1; id <= NewsAlerts.most; id++) {
      await alerts.follow(id, 'Institution $id');
    }
    await expectLater(alerts.follow(99, 'One too many'), throwsStateError);
    expect(alerts.saved, hasLength(NewsAlerts.most));
  });
}
