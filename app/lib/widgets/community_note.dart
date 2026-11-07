import 'package:flutter/material.dart';

import '../brand.dart';
import '../format.dart';
import '../l10n.dart';
import '../models.dart';
import 'mood.dart';

/// "What people said" under a post: the faces of the replies, then the AI's summary of them.
/// In the news list it is the strip, the two most common faces and three lines; on the post
/// screen ([detail]) every face gets a row that can be tapped ([onSelect]) to show only its
/// replies, and the summary comes with the points people raised.
class CommunityNoteBox extends StatelessWidget {
  const CommunityNoteBox({
    super.key,
    this.note,
    this.emotions = const {},
    this.detail = false,
    this.selected,
    this.onSelect,
    this.onReport,
  });

  final CommunityNote? note; // null until the notes writer has run
  final Map<String, int> emotions;
  final bool detail;
  final String? selected;
  final ValueChanged<String?>? onSelect;

  /// Opens the feedback page about this summary (on the post screen only).
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    final read = note?.repliesRead ?? totalOf(emotions);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Brand.sand.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Brand.sand.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.groups_2_outlined,
                  size: 16,
                  color: Brand.sand,
                ),
              ),
              const SizedBox(width: 6),
              // The title and the count share a line, or the count wraps under it with large text.
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        tr('What people said', 'ماذا قال الناس'),
                        style: const TextStyle(
                          color: Brand.sand,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      tr(
                        'from $read ${read == 1 ? 'reply' : 'replies'}',
                        'من $read ردًا',
                      ),
                      style: const TextStyle(color: Brand.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (emotions.isNotEmpty && !detail) ...[
            const SizedBox(height: 10),
            MoodStrip(counts: emotions, height: 8),
            const SizedBox(height: 6),
            // The strip above already says the faces to screen readers, without emoji names.
            ExcludeSemantics(
              child: Text(
                moodHeadline(emotions),
                style: const TextStyle(
                  color: Brand.inkSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (emotions.isNotEmpty && detail) ...[
            const SizedBox(height: 8),
            MoodBars(counts: emotions, selected: selected, onSelect: onSelect),
          ],
          if (note != null) ...[
            const SizedBox(height: 10),
            Text(
              note.summary,
              textDirection: directionOf(note.summary),
              maxLines: detail ? null : 3,
              overflow: detail ? null : TextOverflow.ellipsis,
              style: TextStyle(
                color: Brand.inkSoft,
                fontSize: detail ? 15 : 14,
                height: 1.5,
              ),
            ),
            if (detail && note.keyPoints.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final point in note.keyPoints) _Point(point),
            ],
          ],
          if (detail) ...[
            const SizedBox(height: 8),
            Text(
              tr(
                'Faces and summary written by AI from the public replies. Who wrote them is never stored.',
                'الوجوه والملخص بالذكاء الاصطناعي من الردود العامة. ولا يُحفظ اسم كاتبها.',
              ),
              style: const TextStyle(color: Brand.muted, fontSize: 11.5),
            ),
            if (onReport != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Semantics(
                  hint: tr(
                    'Opens a page to tell the team what is wrong',
                    'يفتح صفحة لإخبار الفريق بالخطأ',
                  ),
                  child: TextButton.icon(
                    onPressed: onReport,
                    icon: const Icon(Icons.flag_outlined, size: 17),
                    label: Text(tr('Report a mistake', 'الإبلاغ عن خطأ')),
                    style: TextButton.styleFrom(
                      foregroundColor: Brand.sand,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Directionality(
      textDirection: directionOf(text),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Icon(Icons.circle, size: 5, color: Brand.sand),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Brand.inkSoft,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
