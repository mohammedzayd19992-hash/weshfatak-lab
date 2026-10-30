import 'package:flutter/material.dart';

import '../brand.dart';
import '../format.dart';
import '../models.dart';
import 'community_note.dart';
import 'media.dart';

/// A post as it appears in the feed, or in full on the post screen ([detail]).
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onOpen,
    this.onComments,
    this.detail = false,
  });

  final NewsPost post;
  final VoidCallback? onOpen;
  final VoidCallback? onComments; // defaults to [onOpen]
  final bool detail;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(post: post),
          const SizedBox(height: 10),
          LinkedText(
            post.body,
            style: TextStyle(
              fontSize: detail ? 17 : 15,
              height: 1.5,
              color: Brand.ink,
            ),
          ),
          if (post.media.isNotEmpty) ...[
            const SizedBox(height: 12),
            MediaGallery(media: post.media, heroTag: 'media-${post.id}'),
          ],
          if (post.communityNote case final note?) ...[
            const SizedBox(height: 12),
            CommunityNoteBox(note: note, detail: detail),
          ],
          if (post.category.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in post.category)
                  TagPill(
                    label: name,
                    icon: categoryIcons[name] ?? Icons.tag,
                    color: Brand.mint,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          _Actions(post: post, onComments: onComments ?? onOpen),
        ],
      ),
    );
    return Container(
      margin: detail
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Brand.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Brand.line),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(20),
          child: content,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.post});

  final NewsPost post;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SourceAvatar(url: post.avatarUrl),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    post.sourceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: directionOf(post.sourceName),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Tooltip(
                  message: 'Verified source',
                  child: Icon(
                    Icons.verified_rounded,
                    size: 16,
                    color: Brand.mint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${post.handle ?? post.organization} · ${shortDate(post.publishedAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Brand.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    ],
  );
}

/// A small rounded label for a news tag.
class TagPill extends StatelessWidget {
  const TagPill({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.30)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

/// Comment count and the link to the original post.
class _Actions extends StatelessWidget {
  const _Actions({required this.post, this.onComments});

  final NewsPost post;
  final VoidCallback? onComments;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _ActionButton(
        icon: Icons.mode_comment_outlined,
        label: '${post.commentCount}',
        tooltip: 'Comments',
        onTap: onComments,
      ),
      const Spacer(),
      _ActionButton(
        icon: Icons.open_in_new_rounded,
        label: 'Source',
        tooltip: 'Open the original post',
        onTap: () => openLink(context, post.sourceLink),
      ),
    ],
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: Brand.muted,
        disabledForegroundColor: Brand.muted,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(44, 40),
        visualDensity: VisualDensity.compact,
      ),
    ),
  );
}
