import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../brand.dart';
import '../format.dart';
import '../l10n.dart';
import '../models.dart';

final _count = intl.NumberFormat.decimalPattern('en');

/// "6,815,504", "83.88%", "2.96 / 5".
String statValue(double value, String? unit) {
  final number = _count.format(value);
  return switch (unit) {
    null => number,
    '%' => '$number%',
    '/5' => '$number / 5',
    _ => '$number $unit',
  };
}

String sectionTitle(String section) => switch (section) {
  'people' => tr('People', 'الناس'),
  'study' => tr('Study', 'الدراسة'),
  'digital' => tr('Digital services', 'الخدمات الرقمية'),
  'research' => tr('Research', 'البحث'),
  _ => section,
};

/// One statistic: the number, what it counts, its period, its bars and where it came from.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.stat});

  final InstitutionStat stat;

  @override
  Widget build(BuildContext context) {
    final stars = stat.unit == '/5';
    final bars = stars ? const <StatBar>[] : stat.breakdown;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: Brand.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Brand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            stat.label,
            textDirection: directionOf(stat.label),
            style: const TextStyle(
              color: Brand.inkSoft,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          // The number and its period share a line, or the period wraps under it with large text.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 10,
            children: [
              Text(
                statValue(stat.value, stat.unit),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  stat.period,
                  textDirection: directionOf(stat.period),
                  style: const TextStyle(color: Brand.muted, fontSize: 12),
                ),
              ),
            ],
          ),
          if (stars) ...[
            const SizedBox(height: 4),
            _Stars(rating: stat.value, ratings: stat.breakdown),
          ],
          if (bars.isNotEmpty) ...[
            const SizedBox(height: 10),
            BarList(bars: bars),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => openLink(context, stat.sourceUrl),
              icon: const Icon(Icons.link_rounded, size: 16),
              label: Text(
                '${tr('Source', 'المصدر')}: ${stat.sourceName}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              style: TextButton.styleFrom(
                foregroundColor: Brand.muted,
                textStyle: const TextStyle(fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A star rating and how many people gave one.
class _Stars extends StatelessWidget {
  const _Stars({required this.rating, required this.ratings});

  final double rating;
  final List<StatBar> ratings; // [{"عدد التقييمات": n}]

  @override
  Widget build(BuildContext context) => Semantics(
    label: [
      tr(
        'Rated ${rating.toStringAsFixed(1)} out of 5',
        'التقييم ${rating.toStringAsFixed(1)} من 5',
      ),
      if (ratings.isNotEmpty)
        tr(
          '${_count.format(ratings.first.value)} ratings',
          '${_count.format(ratings.first.value)} تقييم',
        ),
    ].join(tr(', ', '، ')),
    excludeSemantics: true,
    child: _stars(),
  );

  // The stars and the count share a line, or the count wraps under them with large text.
  Widget _stars() => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    runSpacing: 2,
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          rating >= i - 0.25
              ? Icons.star_rounded
              : rating >= i - 0.75
              ? Icons.star_half_rounded
              : Icons.star_outline_rounded,
          size: 20,
          color: Brand.sand,
        ),
      if (ratings.isNotEmpty) ...[
        const SizedBox(width: 8),
        Text(
          tr(
            '${_count.format(ratings.first.value)} ratings',
            '${_count.format(ratings.first.value)} تقييم',
          ),
          style: const TextStyle(color: Brand.muted, fontSize: 12.5),
        ),
      ],
    ],
  );
}

/// Horizontal bars, largest first, each labeled with its name and value.
class BarList extends StatelessWidget {
  const BarList({super.key, required this.bars});

  final List<StatBar> bars;

  @override
  Widget build(BuildContext context) {
    final most = bars.fold(0.0, (a, bar) => bar.value > a ? bar.value : a);
    final total = bars.fold(0.0, (a, bar) => a + bar.value);
    return Column(
      children: [
        for (final bar in bars)
          MergeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _labelAndValue(context, bar, total),
                  const SizedBox(height: 4),
                  LayoutBuilder(
                    builder: (_, box) => Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        height: 8,
                        width: most == 0 ? 0 : box.maxWidth * bar.value / most,
                        decoration: BoxDecoration(
                          color: Brand.mint,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// The bar's name and its value: side by side, or the value under the name with large text.
  Widget _labelAndValue(BuildContext context, StatBar bar, double total) {
    final large = largeText(context);
    final label = Text(
      bar.label,
      maxLines: large ? 3 : 1,
      overflow: TextOverflow.ellipsis,
      textDirection: directionOf(bar.label),
      style: const TextStyle(color: Brand.inkSoft, fontSize: 12.5),
    );
    final value = Text(
      '${_count.format(bar.value)}  ·  ${total == 0 ? 0 : (100 * bar.value / total).round()}%',
      textDirection: TextDirection.ltr,
      style: const TextStyle(
        color: Brand.ink,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    );
    if (large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [label, value],
      );
    }
    return Row(
      children: [
        Expanded(child: label),
        const SizedBox(width: 8),
        Flexible(child: value),
      ],
    );
  }
}
