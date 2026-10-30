import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../app_name.dart';
import '../brand.dart';
import '../data.dart';
import '../models.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/post_card.dart';
import '../widgets/skeleton.dart';
import 'post_screen.dart';
import 'profile_screen.dart';
import 'alerts_screen.dart';

/// The ministry news feed: newest posts first, more load near the bottom,
/// pull down to refresh. The dock picks who the news is for.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scroll = ScrollController();
  final _seen = <int>{}; // posts that already played their entrance animation
  List<NewsPost> _posts = [];
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;
  int _request = 0;

  FeedFilters get _filters => AppScope.read(context).filters;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    final app = AppScope.read(context);
    Future.microtask(() async {
      await app.loadChoices();
      if (mounted) await _load(reset: true);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (!mounted || (_loading && !reset)) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      if (reset) _error = null;
    });
    try {
      final page = await UniNewsApi.feedPage(
        _filters,
        offset: reset ? 0 : _posts.length,
      );
      if (!mounted || request != _request) return;
      setState(() {
        final known = reset ? <int>{} : {for (final post in _posts) post.id};
        _posts = [
          if (!reset) ..._posts,
          ...page.where((post) => !known.contains(post.id)),
        ];
        _hasMore = page.length == UniNewsApi.pageSize;
        _error = null;
      });
    } catch (error) {
      if (mounted && request == _request) setState(() => _error = error);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 900 &&
        _hasMore &&
        !_loading &&
        _error == null) {
      _load();
    }
  }

  void _setFilters(FeedFilters next) {
    AppScope.read(context).setFilters(next);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _load(reset: true);
  }

  void _toggleAudience(String? audience) {
    HapticFeedback.selectionClick();
    final selected = {..._filters.audiences};
    if (audience == null) {
      selected.clear();
    } else if (!selected.remove(audience)) {
      selected.add(audience);
    }
    _setFilters(_filters.copyWith(audiences: selected));
  }

  Future<void> _openFilters() async {
    final next = await showFilterSheet(context);
    if (next != null && mounted) _setFilters(next);
  }

  Future<void> _openPost(NewsPost post) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => PostScreen(post: post)));
    // Comments may have been added there: refresh this post's count.
    try {
      final fresh = await UniNewsApi.post(post.id);
      if (!mounted) return;
      setState(
        () => _posts = [for (final p in _posts) p.id == fresh.id ? fresh : p],
      );
    } catch (_) {}
  }

  void _openProfile() =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen()));

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final filters = app.filters;
    return Scaffold(
      body: PalmBackdrop(
        child: RefreshIndicator(
          onRefresh: () => _load(reset: true),
          edgeOffset: MediaQuery.paddingOf(context).top + 64,
          backgroundColor: Brand.surfaceHigh,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                toolbarHeight: 64,
                titleSpacing: 16,
                backgroundColor: Brand.night.withValues(alpha: 0.94),
                title: const _BrandTitle(),
                actions: [
                  IconButton(
                    tooltip: 'News alerts',
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AlertsScreen(),
                      ),
                    ),
                  ),
                  _ProfileButton(app: app, onTap: _openProfile),
                  const SizedBox(width: 10),
                ],
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(1),
                  child: Divider(height: 1),
                ),
              ),
              SliverToBoxAdapter(
                child: _Heading(
                  filters: filters,
                  audiences: app.audiences,
                  onFilters: _openFilters,
                ),
              ),
              ..._content(filters),
              SliverToBoxAdapter(
                child: _Footer(
                  loading: _loading && _posts.isNotEmpty,
                  failed: _error != null && _posts.isNotEmpty,
                  finished: !_hasMore && _posts.isNotEmpty,
                  onRetry: _load,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _Dock(
        filters: filters,
        audiences: app.audiences,
        onAudience: _toggleAudience,
        onFilters: _openFilters,
      ),
    );
  }

  List<Widget> _content(FeedFilters filters) {
    if (_posts.isEmpty && _error != null && !_loading) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Message(
            icon: Icons.wifi_off_rounded,
            title: 'Could not load the news',
            text: 'Check your internet connection and try again.',
            action: 'Try again',
            onAction: () => _load(reset: true),
          ),
        ),
      ];
    }
    if (_posts.isEmpty && (_loading || _hasMore)) {
      return [
        SliverList.builder(
          itemCount: 3,
          itemBuilder: (_, _) => const PostSkeleton(),
        ),
      ];
    }
    if (_posts.isEmpty) {
      final filtered = filters.audiences.isNotEmpty || filters.sheetCount > 0;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Message(
            icon: Icons.inbox_outlined,
            title: 'No matching posts',
            text: filtered
                ? 'Try other filters to see more news.'
                : 'News from the Ministry of Education will appear here.',
            action: filtered ? 'Show all news' : null,
            onAction: () => _setFilters(const FeedFilters()),
          ),
        ),
      ];
    }
    return [
      SliverList.builder(
        itemCount: _posts.length,
        itemBuilder: (_, index) {
          final post = _posts[index];
          return _Entrance(
            key: ValueKey(post.id),
            animate: _seen.add(post.id),
            delay: Duration(milliseconds: 60 * (index % UniNewsApi.pageSize)),
            child: PostCard(post: post, onOpen: () => _openPost(post)),
          );
        },
      ),
    ];
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const UniLogo(size: 38),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              appName(context),
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              organizationName.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Brand.sand,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.app, required this.onTap});

  final AppState app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = app.user;
    if (user == null) {
      return IconButton(
        onPressed: onTap,
        tooltip: 'Profile',
        icon: const Icon(Icons.person_outline_rounded),
      );
    }
    return Tooltip(
      message: 'Profile',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: InitialAvatar(name: app.displayName, seed: user.id, size: 34),
        ),
      ),
    );
  }
}

/// "Latest news" and the filters chosen in the filter sheet.
class _Heading extends StatelessWidget {
  const _Heading({
    required this.filters,
    required this.audiences,
    required this.onFilters,
  });

  final FeedFilters filters;
  final List<String> audiences; // in dock order
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Latest news',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          filters.audiences.isEmpty
              ? 'Everything from official sources'
              : 'For ${audiences.where(filters.audiences.contains).join(', ')}',
          style: const TextStyle(color: Brand.muted, fontSize: 14),
        ),
        if (filters.sheetCount > 0) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in filters.categories)
                _FilterTag(
                  label: name,
                  icon: categoryIcons[name] ?? Icons.tag,
                  onTap: onFilters,
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _FilterTag extends StatelessWidget {
  const _FilterTag({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Brand.green.withValues(alpha: 0.16),
    shape: StadiumBorder(
      side: BorderSide(color: Brand.mint.withValues(alpha: 0.35)),
    ),
    child: InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Brand.mint),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Brand.mint,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Fades and lifts a post into place the first time it appears.
class _Entrance extends StatefulWidget {
  const _Entrance({
    super.key,
    required this.animate,
    required this.delay,
    required this.child,
  });

  final bool animate; // only read when the post first appears
  final Duration delay;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance> {
  late final bool _animate = widget.animate;

  @override
  Widget build(BuildContext context) {
    if (!_animate || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    final total = widget.delay + const Duration(milliseconds: 420);
    final start = widget.delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      child: widget.child,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.loading,
    required this.failed,
    required this.finished,
    required this.onRetry,
  });

  final bool loading;
  final bool failed;
  final bool finished;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (loading) {
      child = const SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 2.2),
      );
    } else if (failed) {
      child = TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Could not load more. Try again'),
      );
    } else if (finished) {
      child = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: Brand.muted,
          ),
          SizedBox(width: 8),
          Text("You're all caught up", style: TextStyle(color: Brand.muted)),
        ],
      );
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Center(child: child),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 40, 32, 60),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Brand.surfaceHigh,
            border: Border.all(color: Brand.line),
          ),
          child: Icon(icon, size: 32, color: Brand.mint),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Brand.muted, height: 1.4),
        ),
        if (action != null) ...[
          const SizedBox(height: 18),
          OutlinedButton(onPressed: onAction, child: Text(action!)),
        ],
      ],
    ),
  );
}

/// The bar at the bottom: the filter button and who the news is for.
class _Dock extends StatelessWidget {
  const _Dock({
    required this.filters,
    required this.audiences,
    required this.onAudience,
    required this.onFilters,
  });

  final FeedFilters filters;
  final List<String> audiences;
  final ValueChanged<String?> onAudience;
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Brand.surface,
      border: Border(top: BorderSide(color: Brand.line)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SizedBox(
          height: 42,
          // Equal-width choices that always fit the screen: no sideways scrolling.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FilterButton(active: filters.sheetCount > 0, onTap: onFilters),
              const SizedBox(width: 2),
              _AudienceChip(
                label: 'All',
                selected: filters.audiences.isEmpty,
                onTap: () => onAudience(null),
              ),
              for (final audience in audiences)
                _AudienceChip(
                  label: audienceLabels[audience] ?? audience,
                  selected: filters.audiences.contains(audience),
                  onTap: () => onAudience(audience),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      IconButton.outlined(
        onPressed: onTap,
        tooltip: 'Filters',
        icon: const Icon(Icons.tune_rounded),
        style: IconButton.styleFrom(
          foregroundColor: Brand.mint,
          fixedSize: const Size(42, 42),
          side: const BorderSide(color: Brand.lineStrong),
        ),
      ),
      if (active)
        Positioned(
          right: 2,
          top: 2,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: Brand.sand,
              shape: BoxShape.circle,
              border: Border.all(color: Brand.surface, width: 1.5),
            ),
          ),
        ),
    ],
  );
}

class _AudienceChip extends StatelessWidget {
  const _AudienceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(left: 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? Brand.green : Brand.surfaceHigh,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Brand.green : Brand.line),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                // Shrinks the label on very narrow phones or large text settings.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: selected ? Colors.white : Brand.inkSoft,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
