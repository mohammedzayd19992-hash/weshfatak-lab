import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with WidgetsBindingObserver {
  bool _allowed = false;
  bool _important = true;
  bool _busy = false;
  bool get _ar =>
      WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'ar';
  String tr(String en, String ar) => _ar ? ar : en;

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
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message
                  : tr(
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

  String describe(FeedFilters filters) => [
    filters.audiences.isEmpty
        ? tr('All audiences', 'كل الفئات')
        : filters.audiences.join(', '),
    filters.categories.isEmpty
        ? tr('All categories', 'كل التصنيفات')
        : filters.categories.join(', '),
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final alerts = app.alerts;
    return Scaffold(
      appBar: AppBar(title: Text(tr('News alerts', 'تنبيهات الأخبار'))),
      body: AnimatedBuilder(
        animation: alerts,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              tr(
                'Get new stories for each saved filter, even when the app is closed.',
                'تصلك الأخبار الجديدة لكل فلتر محفوظ، حتى عند إغلاق التطبيق.',
              ),
            ),
            const SizedBox(height: 12),
            if (!alerts.supported)
              Text(
                tr(
                  'News alerts are available in the Android app.',
                  'تنبيهات الأخبار متاحة في تطبيق أندرويد.',
                ),
              ),
            if (alerts.supported && !_allowed) ...[
              Text(
                tr(
                  'Allow notifications in Android settings to receive alerts.',
                  'اسمح بالإشعارات في إعدادات أندرويد لتصلك التنبيهات.',
                ),
              ),
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
            const SizedBox(height: 12),
            Text(
              tr('Current feed filter', 'فلتر الأخبار الحالي'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(describe(app.filters)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _important,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _important = value),
              title: Text(
                tr('Important categories only', 'التصنيفات المهمة فقط'),
              ),
              subtitle: Text(
                tr(
                  'Academic, exams and administrative news. Activities are excluded.',
                  'الأخبار الأكاديمية والاختبارات والإدارية. لا تشمل الأنشطة.',
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: !alerts.supported || _busy
                  ? null
                  : () => _run(() async {
                      if (!await alerts.permission(request: true)) {
                        await _refresh();
                        return;
                      }
                      await alerts.add(app.filters, importantOnly: _important);
                      await _refresh();
                    }),
              icon: const Icon(Icons.notification_add_outlined),
              label: Text(
                tr('Save alert for this filter', 'حفظ تنبيه لهذا الفلتر'),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              tr('Saved alerts', 'التنبيهات المحفوظة'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (alerts.saved.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  tr('No saved alerts yet.', 'لا توجد تنبيهات محفوظة بعد.'),
                ),
              ),
            for (final item in alerts.saved)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
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
                        title: Text(describe(item.filters)),
                        subtitle: Text(
                          item.importantOnly
                              ? tr(
                                  'Important categories only',
                                  'التصنيفات المهمة فقط',
                                )
                              : tr('All matching news', 'كل الأخبار المطابقة'),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(() => alerts.remove(item.id)),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(tr('Remove', 'إزالة')),
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
      ),
    );
  }
}
