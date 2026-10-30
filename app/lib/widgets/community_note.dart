import 'package:flutter/material.dart';

import '../brand.dart';
import '../format.dart';
import '../models.dart';

/// The community note under a post: what people said in reply, as Claude summarized it.
/// The post screen ([detail]) adds the points people raised.
class CommunityNoteBox extends StatelessWidget {
  const CommunityNoteBox({super.key, required this.note, this.detail = false});

  final CommunityNote note;
  final bool detail;

  @override
  Widget build(BuildContext context) => Container(
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
          children: [
            const Icon(Icons.groups_2_outlined, size: 16, color: Brand.sand),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Community note',
                style: TextStyle(
                  color: Brand.sand,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              'from ${note.repliesRead} '
              '${note.repliesRead == 1 ? 'reply' : 'replies'}',
              style: const TextStyle(color: Brand.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
        if (detail) ...[
          const SizedBox(height: 8),
          const Text(
            'Written by Claude from public replies on X and comments in this app.',
            style: TextStyle(color: Brand.muted, fontSize: 11.5),
          ),
        ],
      ],
    ),
  );
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
