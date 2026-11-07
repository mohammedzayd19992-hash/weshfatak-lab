import 'package:flutter/material.dart';

import '../brand.dart';
import '../config.dart';
import '../data.dart';
import '../l10n.dart';
import '../screens/about_screen.dart';
import 'info.dart';

// ---------------------------------------------------------------------------
// How old the data is (plain functions, so they can be tested on their own)
// ---------------------------------------------------------------------------

/// The home screen's line: "Prototype · data up to Wed Nov 4", or "· updated 3 h ago" while
/// the collectors run.
String prototypeLine(DateTime? at, {DateTime? now}) {
  final prototype = tr('Prototype', 'نموذج أولي');
  if (at == null) return prototype;
  return dataIsOld(at, now: now)
      ? '$prototype · ${tr('data up to ${dayLabel(at, now: now)}', 'البيانات حتى ${dayLabel(at, now: now)}')}'
      : '$prototype · ${tr('updated ${timeAgo(at, now: now)}', 'حُدّث ${timeAgo(at, now: now)}')}';
}

/// What the About page says about the data: made up, paused, or collected by itself.
String? collectionLine(DateTime? at, {required bool demo, DateTime? now}) {
  if (demo) {
    return tr(
      'This copy shows made-up institutions and news.',
      'هذه النسخة تعرض جهات وأخبارًا من الخيال.',
    );
  }
  if (at == null) return null;
  if (dataIsOld(at, now: now)) {
    final day = dayLabel(at, now: now);
    return tr(
      'Collection is paused for now, so the news, replies and study status stop at $day.',
      'الجمع متوقف حاليًا، فالأخبار والردود وحالة الدراسة تقف عند $day.',
    );
  }
  return tr(
    'Collected automatically every few hours, last ${timeAgo(at, now: now)}.',
    'يُجمع تلقائيًا كل بضع ساعات، وآخر مرة ${timeAgo(at, now: now)}.',
  );
}

// ---------------------------------------------------------------------------

/// Under the home screen's title in a prototype build: that it is a prototype, how old its data
/// is, and the way to the About page.
class PrototypeNote extends StatelessWidget {
  const PrototypeNote({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isPrototype) return const SizedBox.shrink();
    return ValueListenableBuilder<DateTime?>(
      valueListenable: UniNewsApi.collectedAt,
      builder: (context, at, _) {
        final old = dataIsOld(at);
        final line = prototypeLine(at);
        final about = tr('About this prototype', 'عن هذا النموذج الأولي');
        return Semantics(
          button: true,
          label: '$line. $about',
          excludeSemantics: true,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              ),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Brand.sand.withValues(alpha: old ? 0.1 : 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Brand.sand.withValues(alpha: old ? 0.45 : 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      old ? Icons.history_rounded : Icons.science_outlined,
                      size: 18,
                      color: Brand.sand,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        line,
                        style: const TextStyle(
                          color: Brand.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('About', 'حول'),
                      style: const TextStyle(
                        color: Brand.sand,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Brand.sand,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
