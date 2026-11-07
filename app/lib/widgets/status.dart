import 'package:flutter/material.dart';

import '../brand.dart';
import '../data.dart';
import '../l10n.dart';
import 'info.dart';

/// A line at the top of a page when it is not showing live news: in the demo, or when the database
/// could not be reached and the page shows what the phone kept from last time. Screen readers
/// announce it when it appears.
class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, this.showDemo = true});

  /// Whether to say this is the demo (the home and institution pages do, a post page does not).
  final bool showDemo;

  @override
  Widget build(BuildContext context) {
    if (UniNewsApi.demoMode) {
      return showDemo
          ? _Line(
              icon: Icons.science_outlined,
              color: Brand.sand,
              text: tr(
                'Demo: made-up institutions and news, to try the app without a database.',
                'نسخة تجريبية: جهات وأخبار من الخيال لتجربة التطبيق دون قاعدة بيانات.',
              ),
            )
          : const SizedBox.shrink();
    }
    return ValueListenableBuilder<DateTime?>(
      valueListenable: UniNewsApi.offlineSince,
      builder: (context, since, _) => since == null
          ? const SizedBox.shrink()
          : _Line(
              icon: Icons.cloud_off_rounded,
              color: Brand.sand,
              text: tr(
                'No connection: showing what was saved ${timeAgo(since)}.',
                'لا يوجد اتصال: يُعرض ما حُفظ ${timeAgo(since)}.',
              ),
            ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border(
          bottom: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Brand.ink,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
