import 'package:flutter/material.dart';

import '../brand.dart';
import '../format.dart';
import '../l10n.dart';

/// One face of the mood chart. The order runs from glad to angry, and each face keeps its
/// color everywhere. The colors pass the colorblind and contrast checks on the app's dark
/// surface in this order; neutral is gray on purpose, the midpoint.
class Face {
  const Face(this.key, this.emoji, this.en, this.ar, this.color);

  final String key; // as stored in the database
  final String emoji;
  final String en;
  final String ar;
  final Color color;

  String get label => tr(en, ar);
}

const faces = [
  Face('happy', '😄', 'Happy', 'سعيد', Color(0xFF199E70)),
  Face('asking', '🤔', 'Asking', 'يسأل', Color(0xFF3987E5)),
  Face('neutral', '😐', 'Neutral', 'محايد', Color(0xFF6F716B)),
  Face('worried', '😟', 'Worried', 'قلق', Color(0xFFC98500)),
  Face('sarcastic', '🙃', 'Sarcastic', 'ساخر', Color(0xFFD55181)),
  Face('sad', '😢', 'Sad', 'حزين', Color(0xFF9085E9)),
  Face('angry', '😠', 'Angry', 'غاضب', Color(0xFFE66767)),
];

Face? faceFor(String? key) {
  for (final face in faces) {
    if (face.key == key) return face;
  }
  return null;
}

int totalOf(Map<String, int> counts) =>
    counts.values.fold(0, (sum, n) => sum + n);

int percent(int n, int total) => total == 0 ? 0 : (100 * n / total).round();

/// "😠 56% angry · 😄 19% happy": the two most common faces.
String moodHeadline(Map<String, int> counts) {
  final total = totalOf(counts);
  final top = [
    for (final face in faces)
      if ((counts[face.key] ?? 0) > 0) face,
  ]..sort((a, b) => counts[b.key]!.compareTo(counts[a.key]!));
  return top
      .take(2)
      .map(
        (face) =>
            '${face.emoji} ${percent(counts[face.key]!, total)}% ${face.label}',
      )
      .join('  ·  ');
}

/// What a screen reader says for the mood, without emoji names: "56% angry, 19% happy".
String moodSpoken(Map<String, int> counts, {int most = 2}) {
  final total = totalOf(counts);
  final top = [
    for (final face in faces)
      if ((counts[face.key] ?? 0) > 0) face,
  ]..sort((a, b) => counts[b.key]!.compareTo(counts[a.key]!));
  return top
      .take(most)
      .map((face) => '${percent(counts[face.key]!, total)}% ${face.label}')
      .join(tr(', ', '، '));
}

/// All the faces as one thin bar, in face order, with a gap of surface between them.
class MoodStrip extends StatelessWidget {
  const MoodStrip({super.key, required this.counts, this.height = 10});

  final Map<String, int> counts;
  final double height;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final face in faces)
        if ((counts[face.key] ?? 0) > 0) face,
    ];
    return Semantics(
      label:
          '${tr('Replies', 'الردود')}: ${moodSpoken(counts, most: faces.length)}',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: height,
          child: Row(
            // Stretched, or the empty colored boxes would have no height.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, face) in shown.indexed) ...[
                if (index > 0) const SizedBox(width: 2),
                Expanded(
                  flex: counts[face.key]!,
                  child: ColoredBox(color: face.color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The faces of a post's replies, one row each with its share and count, for the post screen.
/// Tapping a row picks that face ([onSelect]), so the replies below can show only it.
class MoodBars extends StatelessWidget {
  const MoodBars({
    super.key,
    required this.counts,
    this.selected,
    this.onSelect,
  });

  final Map<String, int> counts;
  final String? selected;
  final ValueChanged<String?>? onSelect;

  @override
  Widget build(BuildContext context) {
    final total = totalOf(counts);
    final most = counts.values.fold(0, (a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final face in faces)
          if ((counts[face.key] ?? 0) > 0)
            _FaceRow(
              face: face,
              count: counts[face.key]!,
              total: total,
              most: most,
              selected: selected == face.key,
              onTap: onSelect == null
                  ? null
                  : () => onSelect!(selected == face.key ? null : face.key),
            ),
        if (total < 10) ...[
          const SizedBox(height: 4),
          Text(
            tr(
              'Only $total replies so far: read this with care.',
              'عدد الردود $total فقط حتى الآن، فاقرأ النتيجة بحذر.',
            ),
            style: const TextStyle(color: Brand.sand, fontSize: 12),
          ),
        ],
        if (onSelect != null) ...[
          const SizedBox(height: 4),
          Text(
            tr(
              'Tap a face to see only its replies below.',
              'اضغط على وجه لعرض ردوده فقط في الأسفل.',
            ),
            style: const TextStyle(color: Brand.muted, fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

class _FaceRow extends StatelessWidget {
  const _FaceRow({
    required this.face,
    required this.count,
    required this.total,
    required this.most,
    required this.selected,
    this.onTap,
  });

  final Face face;
  final int count;
  final int total;
  final int most;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final emoji = ExcludeSemantics(
      child: Text(face.emoji, style: const TextStyle(fontSize: 20)),
    );
    final label = Text(
      face.label,
      style: TextStyle(
        color: Brand.inkSoft,
        fontSize: 13.5,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
    final bar = ExcludeSemantics(
      child: LayoutBuilder(
        builder: (_, box) => Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            height: 8,
            width: box.maxWidth * count / most,
            decoration: BoxDecoration(
              color: face.color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
    final share = Text(
      '${percent(count, total)}%  ($count)',
      textAlign: TextAlign.end,
      semanticsLabel: tr(
        '${percent(count, total)} percent, $count ${count == 1 ? 'reply' : 'replies'}',
        '${percent(count, total)} بالمئة، $count من الردود',
      ),
      style: const TextStyle(
        color: Brand.ink,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    );
    // With large text the fixed columns would not fit a phone, so the bar goes under the words.
    final Widget content = largeText(context)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  emoji,
                  const SizedBox(width: 8),
                  Expanded(child: label),
                  const SizedBox(width: 8),
                  share,
                ],
              ),
              const SizedBox(height: 6),
              bar,
            ],
          )
        : Row(
            children: [
              emoji,
              const SizedBox(width: 8),
              SizedBox(width: 74, child: label),
              Expanded(child: bar),
              const SizedBox(width: 10),
              SizedBox(width: 64, child: share),
            ],
          );
    return MergeSemantics(
      child: Semantics(
        selected: selected,
        button: onTap != null,
        hint: onTap == null
            ? null
            : selected
            ? tr('Shows all replies again', 'يعرض كل الردود مرة أخرى')
            : tr('Shows only these replies', 'يعرض هذه الردود فقط'),
        child: Material(
          color: selected ? Brand.surfaceHigher : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A face as a small label, for one reply.
class FaceTag extends StatelessWidget {
  const FaceTag({super.key, required this.face});

  final Face face;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: face.color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: face.color.withValues(alpha: 0.45)),
    ),
    child: Text(
      '${face.emoji} ${face.label}',
      semanticsLabel: tr('Face: ${face.label}', 'الوجه: ${face.label}'),
      style: const TextStyle(
        color: Brand.inkSoft,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
