import 'package:flutter/material.dart';

import '../brand.dart';
import '../format.dart';
import '../l10n.dart';
import '../models.dart';
import 'community_note.dart';
import 'media.dart';

/// A post as it appears in the news list, or in full on the post screen ([detail]), with what
/// people said about it. On the post screen tapping a face ([onSelectFace]) filters the replies.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onOpen,
    this.onComments,
    this.detail = false,
    this.selectedFace,
    this.onSelectFace,
  });

  final NewsPost post;
  final VoidCallback? onOpen;
  final VoidCallback? onComments; // the replies button; defaults to [onOpen]
  final bool detail;
  final String? selectedFace;
  final ValueChanged<String?>? onSelectFace;

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
          if (post.alsoIn.isNotEmpty) ...[
            const SizedBox(height: 12),
            AlsoReported(copies: post.alsoIn, detail: detail),
          ],
          if (post.communityNote != null || post.emotions.isNotEmpty) ...[
            const SizedBox(height: 12),
            CommunityNoteBox(
              note: post.communityNote,
              emotions: post.emotions,
              detail: detail,
              selected: selectedFace,
              onSelect: onSelectFace,
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
      // Its own group for a screen reader; the links and buttons inside stay separate items.
      child: Semantics(
        container: true,
        button: onOpen != null,
        label: tr('Story from ${post.sourceName}', 'خبر من ${post.sourceName}'),
        hint: onOpen == null
            ? null
            : tr('Opens the story and its replies', 'يفتح الخبر وردوده'),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(20),
            child: content,
          ),
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
      if (post.isPress && post.avatarUrl == null)
        const ExcludeSemantics(child: _PressAvatar())
      else
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
                if (post.isPress)
                  Tooltip(
                    message: tr(
                      'A press report about the institution',
                      'خبر صحفي عن الجهة',
                    ),
                    child: const Icon(
                      Icons.newspaper_rounded,
                      size: 16,
                      color: Brand.sand,
                    ),
                  )
                else
                  Tooltip(
                    message: tr('Official source', 'مصدر رسمي'),
                    child: const Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: Brand.mint,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${platformLabel(post.platform)} · ${post.handle ?? post.organization} · ${shortDate(post.publishedAt)}',
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

/// Where a post came from, in a word.
String platformLabel(String platform) => switch (platform) {
  'x' => 'X',
  'instagram' => 'Instagram',
  'youtube' => 'YouTube',
  'app_store' => 'App Store',
  'media' => tr('Press', 'الصحافة'),
  _ => tr('Website', 'الموقع'),
};

IconData platformIcon(String platform) => switch (platform) {
  'x' => Icons.alternate_email_rounded,
  'rss' => Icons.rss_feed_rounded,
  'instagram' => Icons.photo_camera_outlined,
  'snapchat' => Icons.chat_bubble_outline_rounded,
  'youtube' => Icons.smart_display_outlined,
  'linkedin' => Icons.work_outline_rounded,
  'app_store' || 'google_play' => Icons.phone_iphone_rounded,
  'open_data' => Icons.dataset_outlined,
  'media' => Icons.newspaper_rounded,
  _ => Icons.language_rounded,
};

class _PressAvatar extends StatelessWidget {
  const _PressAvatar();

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Brand.surfaceHigher,
      border: Border.all(color: Brand.sand.withValues(alpha: 0.45)),
    ),
    child: const Icon(Icons.newspaper_rounded, color: Brand.sand, size: 22),
  );
}

/// The same story on the institution's other channels and in the press. Each chip opens that
/// copy; a source that posted it twice shows once. The list shows four, the post page all.
class AlsoReported extends StatelessWidget {
  const AlsoReported({super.key, required this.copies, this.detail = false});

  final List<StoryCopy> copies;
  final bool detail;

  static String labelOf(StoryCopy copy) =>
      copy.isPress ? copy.sourceName : platformLabel(copy.platform);

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final unique = [
      for (final copy in copies)
        if (seen.add(labelOf(copy))) copy,
    ];
    final shown = detail ? unique : unique.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('Also reported by', 'ورد الخبر أيضًا في'),
          style: const TextStyle(
            color: Brand.muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final copy in shown)
              ActionChip(
                avatar: Icon(
                  platformIcon(copy.platform),
                  size: 15,
                  color: copy.isPress ? Brand.sand : Brand.mint,
                ),
                label: Text(labelOf(copy)),
                tooltip: tr('Open this report', 'افتح هذا الخبر'),
                onPressed: () => openLink(context, copy.url),
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(
                  color: Brand.inkSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: Brand.surfaceHigh,
                side: const BorderSide(color: Brand.line),
              ),
            if (unique.length > shown.length)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '+${unique.length - shown.length}',
                  semanticsLabel: tr(
                    '${unique.length - shown.length} more on the story page',
                    '${unique.length - shown.length} أخرى في صفحة الخبر',
                  ),
                  style: const TextStyle(color: Brand.muted, fontSize: 12.5),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Reply count and the link to the original post.
class _Actions extends StatelessWidget {
  const _Actions({required this.post, this.onComments});

  final NewsPost post;
  final VoidCallback? onComments;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (post.replyCount > 0)
        _ActionButton(
          icon: Icons.forum_outlined,
          label: '${post.replyCount}',
          tooltip: tr('Replies', 'الردود'),
          onTap: onComments,
        ),
      const Spacer(),
      _ActionButton(
        icon: Icons.open_in_new_rounded,
        label: tr('Source', 'المصدر'),
        tooltip: tr('Open the original post', 'افتح المنشور الأصلي'),
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
        minimumSize: const Size(
          48,
          48,
        ), // the smallest target a finger hits reliably
      ),
    ),
  );
}
