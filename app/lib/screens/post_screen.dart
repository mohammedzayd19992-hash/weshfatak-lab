import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../brand.dart';
import '../data.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/auth_sheet.dart';
import '../widgets/post_card.dart';

/// One post with the replies people left on X and the comments in the app.
/// Guests read; members can also comment.
class PostScreen extends StatefulWidget {
  const PostScreen({super.key, required this.post});

  final NewsPost post;

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  late NewsPost _post = widget.post;
  List<PublicReply>? _replies;
  List<Comment>? _comments;
  Object? _error;
  bool _sending = false;
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final (post, replies, comments) = await (
        UniNewsApi.post(_post.id),
        UniNewsApi.replies(_post.id),
        UniNewsApi.comments(_post.id),
      ).wait;
      if (!mounted) return;
      setState(() {
        _post = post;
        _replies = replies;
        _comments = comments;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await UniNewsApi.addComment(_post.id, text);
      _input.clear();
      HapticFeedback.lightImpact();
      await _refresh();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
          );
        }
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your comment was not posted. Check your connection and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _signIn() async {
    final signedIn = await showAuthSheet(
      context,
      reason: 'Sign in to comment on this post.',
    );
    if (signedIn && mounted) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: PalmBackdrop(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                backgroundColor: Brand.surfaceHigh,
                child: ListView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                  children: [
                    PostCard(
                      post: _post,
                      detail: true,
                      onComments: app.signedIn ? _focus.requestFocus : _signIn,
                    ),
                    if (_replies case final replies? when replies.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _RepliesPanel(replies: replies),
                    ],
                    const SizedBox(height: 12),
                    _CommentsPanel(
                      comments: _comments,
                      failed: _error != null,
                      onRetry: _refresh,
                    ),
                  ],
                ),
              ),
            ),
            _Composer(
              app: app,
              controller: _input,
              focus: _focus,
              sending: _sending,
              onSend: _send,
              onSignIn: _signIn,
            ),
          ],
        ),
      ),
    );
  }
}

/// What people replied under the post on X, most liked first. No names: the collector
/// keeps only the text, the time and the likes.
class _RepliesPanel extends StatelessWidget {
  const _RepliesPanel({required this.replies});

  final List<PublicReply> replies;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    decoration: BoxDecoration(
      color: Brand.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Brand.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Replies on X',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            _CountBadge(replies.length),
          ],
        ),
        for (final (index, reply) in replies.indexed) ...[
          if (index > 0) const Divider(height: 1),
          _ReplyTile(reply: reply),
        ],
      ],
    ),
  );
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({required this.reply});

  final PublicReply reply;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    // Likes and date sit on the same side the reply's text starts.
    child: Directionality(
      textDirection: directionOf(reply.body),
      child: _ReplyContent(reply: reply),
    ),
  );
}

class _ReplyContent extends StatelessWidget {
  const _ReplyContent({required this.reply});

  final PublicReply reply;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        reply.body,
        style: const TextStyle(
          color: Brand.inkSoft,
          fontSize: 14.5,
          height: 1.45,
        ),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          if (reply.likes > 0) ...[
            const Icon(
              Icons.favorite_border_rounded,
              size: 14,
              color: Brand.muted,
            ),
            const SizedBox(width: 4),
            Text(
              '${reply.likes}  ·  ',
              style: const TextStyle(color: Brand.muted, fontSize: 12),
            ),
          ],
          Text(
            shortDate(reply.postedAt),
            style: const TextStyle(color: Brand.muted, fontSize: 12),
          ),
        ],
      ),
    ],
  );
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
      style: const TextStyle(
        color: Brand.mint,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _CommentsPanel extends StatelessWidget {
  const _CommentsPanel({
    required this.comments,
    required this.failed,
    required this.onRetry,
  });

  final List<Comment>? comments;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final list = comments;
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
          Row(
            children: [
              const Text(
                'Comments in the app',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              if (list != null && list.isNotEmpty) ...[
                const SizedBox(width: 8),
                _CountBadge(list.length),
              ],
            ],
          ),
          if (list == null && !failed)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            ),
          if (list == null && failed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Could not load comments. Try again'),
              ),
            ),
          if (list != null && list.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 14, 0, 18),
              child: Text(
                'No comments yet. Be the first to share your thoughts.',
                style: TextStyle(color: Brand.muted),
              ),
            ),
          if (list != null)
            for (final (index, comment) in list.indexed) ...[
              if (index > 0) const Divider(height: 1),
              _CommentTile(comment: comment),
            ],
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InitialAvatar(name: comment.authorName, seed: comment.userId, size: 34),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comment.authorName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                width: double.infinity,
                child: Text(
                  comment.body,
                  textDirection: directionOf(comment.body),
                  style: const TextStyle(
                    color: Brand.inkSoft,
                    fontSize: 14.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// The comment box for members, or a sign in button for guests.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.app,
    required this.controller,
    required this.focus,
    required this.sending,
    required this.onSend,
    required this.onSignIn,
  });

  final AppState app;
  final TextEditingController controller;
  final FocusNode focus;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final user = app.user;
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: const BorderSide(color: Brand.line),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Brand.surface,
        border: Border(top: BorderSide(color: Brand.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: user == null
              ? FilledButton.icon(
                  onPressed: onSignIn,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign in to comment'),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: InitialAvatar(
                        name: app.displayName,
                        seed: user.id,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focus,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 1000,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Write a comment',
                          counterText: '',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 13,
                          ),
                          border: pill,
                          enabledBorder: pill,
                          focusedBorder: pill.copyWith(
                            borderSide: const BorderSide(
                              color: Brand.mint,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (_, value, _) => IconButton.filled(
                        onPressed: sending || value.text.trim().isEmpty
                            ? null
                            : onSend,
                        tooltip: 'Post comment',
                        style: IconButton.styleFrom(
                          backgroundColor: Brand.green,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Brand.surfaceHigher,
                          disabledForegroundColor: Brand.muted,
                          fixedSize: const Size(46, 46),
                        ),
                        icon: sending
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
