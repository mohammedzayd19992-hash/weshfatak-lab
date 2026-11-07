import 'package:flutter/material.dart';

import '../brand.dart';
import '../data.dart';
import '../format.dart';
import '../l10n.dart';
import '../models.dart';
import '../widgets/mood.dart';
import '../widgets/post_card.dart';
import '../widgets/status.dart';

/// One post with how people felt about it and the replies they left. Tapping a face shows
/// only the replies with that face.
class PostScreen extends StatefulWidget {
  const PostScreen({super.key, required this.post});

  final NewsPost post;

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  late NewsPost _post = widget.post;
  List<PublicReply>? _replies;
  Object? _error;
  String? _face;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final (post, replies) = await (
        UniNewsApi.post(_post.id),
        UniNewsApi.replies(_post.id),
      ).wait;
      if (!mounted) return;
      setState(() {
        _post = post;
        _replies = replies;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  /// Goes down to the replies; at once when the phone asks for no animations.
  void _toReplies() {
    final end = _scroll.position.maxScrollExtent;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(end);
    } else {
      _scroll.animateTo(
        end,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final replies = _replies;
    final shown = replies == null
        ? null
        : _face == null
        ? replies
        : replies.where((reply) => reply.emotion == _face).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_post.sourceName),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: PalmBackdrop(
        child: RefreshIndicator(
          onRefresh: _refresh,
          backgroundColor: Brand.surfaceHigh,
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              const StatusBanner(showDemo: false),
              PostCard(
                post: _post,
                detail: true,
                onComments: _toReplies,
                selectedFace: _face,
                onSelectFace: (face) => setState(() => _face = face),
              ),
              const SizedBox(height: 12),
              _RepliesPanel(
                replies: shown,
                platform: _post.platform,
                face: faceFor(_face),
                onShowAll: () => setState(() => _face = null),
                failed: _error != null,
                onRetry: _refresh,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What people replied under the post on X (or commented under a YouTube video), most liked
/// first, or only those with the face picked in the summary above. No names: the collector keeps
/// only the text, the time and the likes.
class _RepliesPanel extends StatelessWidget {
  const _RepliesPanel({
    required this.replies,
    required this.platform,
    required this.face,
    required this.onShowAll,
    required this.failed,
    required this.onRetry,
  });

  final List<PublicReply>? replies;
  final String platform;
  final Face? face;
  final VoidCallback onShowAll;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final list = replies;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: Brand.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Brand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The title and the picked face share a line when they fit, and wrap with large text.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Semantics(
                      header: true,
                      child: Text(
                        platform == 'youtube'
                            ? tr('Comments on YouTube', 'التعليقات على يوتيوب')
                            : tr('Replies on X', 'الردود على إكس'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (list != null && list.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _CountBadge(list.length),
                  ],
                ],
              ),
              // One full-size target that shows all replies again; the cross only shows how.
              if (face case final face?)
                ActionChip(
                  avatar: const Icon(Icons.close_rounded, size: 18),
                  label: Text(
                    '${face.emoji} ${face.label}',
                    semanticsLabel: tr(
                      'Showing only: ${face.label}',
                      'المعروض فقط: ${face.label}',
                    ),
                  ),
                  tooltip: tr('Show all replies', 'اعرض كل الردود'),
                  onPressed: onShowAll,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                ),
            ],
          ),
          if (list == null && !failed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    semanticsLabel: tr('Loading replies', 'جارٍ تحميل الردود'),
                  ),
                ),
              ),
            ),
          if (list == null && failed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  tr(
                    'Could not load replies. Try again',
                    'تعذر تحميل الردود. حاول مرة أخرى',
                  ),
                ),
              ),
            ),
          if (list != null && list.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 18),
              child: Text(
                face != null
                    ? tr(
                        'No replies with this face.',
                        'لا توجد ردود بهذا الوجه.',
                      )
                    : platform == 'x' || platform == 'youtube'
                    ? tr(
                        'No replies collected for this post.',
                        'لم تُجمع ردود على هذا المنشور.',
                      )
                    : tr(
                        'Readers cannot reply on this source. When the institution posts the same story on X, its replies show here.',
                        'لا يمكن الرد على هذا المصدر. عندما تنشر الجهة الخبر نفسه على إكس تظهر ردوده هنا.',
                      ),
                style: const TextStyle(color: Brand.muted),
              ),
            ),
          if (list != null)
            for (final (index, reply) in list.indexed) ...[
              if (index > 0) const Divider(height: 1),
              _ReplyTile(reply: reply),
            ],
        ],
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({required this.reply});

  final PublicReply reply;

  @override
  Widget build(BuildContext context) {
    final face = faceFor(reply.emotion);
    // One item for a screen reader: the reply, its face, its likes and its date.
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              reply.body,
              textDirection: directionOf(reply.body),
              style: const TextStyle(
                color: Brand.inkSoft,
                fontSize: 14.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            // Face, likes and date share a line, and wrap with large text.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                if (face != null) FaceTag(face: face),
                if (reply.likes > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite_border_rounded,
                        size: 14,
                        color: Brand.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${reply.likes}',
                        semanticsLabel: tr(
                          '${reply.likes} ${reply.likes == 1 ? 'like' : 'likes'}',
                          '${reply.likes} إعجاب',
                        ),
                        style: const TextStyle(
                          color: Brand.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                Text(
                  shortDate(reply.postedAt),
                  style: const TextStyle(color: Brand.muted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Brand.green.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      '$count',
      semanticsLabel: tr(
        '$count ${count == 1 ? 'reply' : 'replies'}',
        '$count من الردود',
      ),
      style: const TextStyle(
        color: Brand.mint,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
