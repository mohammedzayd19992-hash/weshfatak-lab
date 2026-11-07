import 'package:flutter/material.dart';

import '../app_state.dart';
import '../brand.dart';
import '../l10n.dart';

/// The institutions the phone follows. Follow one with the bell on its page.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with WidgetsBindingObserver {
  bool _allowed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final allowed = await AppScope.read(context).alerts.permission();
    if (mounted) setState(() => _allowed = allowed);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'Could not update alerts. Try again.',
                'تعذر تحديث التنبيهات. حاول مرة أخرى.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alerts = AppScope.of(context).alerts;
    return Scaffold(
      appBar: AppBar(title: Text(tr('News alerts', 'تنبيهات الأخبار'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            tr(
              'Get each new post from the institutions you follow, even when the app is closed. Tap the bell on an institution\'s page to follow it.',
              'يصلك كل خبر جديد من الجهات التي تتابعها، حتى عند إغلاق التطبيق. اضغط على الجرس في صفحة الجهة لمتابعتها.',
            ),
            style: const TextStyle(height: 1.45),
          ),
          const SizedBox(height: 12),
          if (!alerts.supported)
            Text(
              tr(
                'News alerts are available in the Android app.',
                'تنبيهات الأخبار متاحة في تطبيق أندرويد.',
              ),
              style: const TextStyle(color: Brand.sand),
            ),
          if (alerts.supported && !_allowed) ...[
            Text(
              tr(
                'Allow notifications in Android settings to receive alerts.',
                'اسمح بالإشعارات في إعدادات أندرويد لتصلك التنبيهات.',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      await alerts.permission(request: true);
                      await _refresh();
                    }),
              child: Text(tr('Allow notifications', 'السماح بالإشعارات')),
            ),
          ],
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              tr('Following', 'تتابعها'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (alerts.saved.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                tr(
                  'You do not follow any institution yet.',
                  'لا تتابع أي جهة بعد.',
                ),
                style: const TextStyle(color: Brand.muted),
              ),
            ),
          for (final item in alerts.saved)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: item.enabled,
                        onChanged: _busy
                            ? null
                            : (value) => _run(() async {
                                if (value &&
                                    !await alerts.permission(request: true)) {
                                  await _refresh();
                                  return;
                                }
                                await alerts.toggle(item.id, value);
                              }),
                        title: Text(item.name),
                        subtitle: Text(
                          item.enabled
                              ? tr('Alerts on', 'التنبيهات مفعلة')
                              : tr('Paused', 'متوقفة'),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: tr('Remove', 'إزالة'),
                      onPressed: _busy
                          ? null
                          : () => _run(() => alerts.remove(item.id)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            tr(
              'Android checks periodically, usually every 15 minutes or longer. Battery settings can delay alerts. After Force stop, open the app again to resume.',
              'يفحص أندرويد الأخبار دوريًا، عادة كل ١٥ دقيقة أو أكثر. قد تؤخر إعدادات البطارية التنبيهات. بعد الإيقاف الإجباري افتح التطبيق لاستئنافها.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
