import 'package:flutter/material.dart';

import '../app_state.dart';
import '../brand.dart';
import '../data.dart';
import '../format.dart';
import '../l10n.dart';
import '../models.dart';
import '../widgets/info.dart';
import '../widgets/post_card.dart';
import '../widgets/skeleton.dart';
import '../widgets/stats.dart';
import '../widgets/status.dart';
import 'home_screen.dart';
import 'post_screen.dart';

/// One institution's page: its news, each post with what people said about it, then its
/// numbers and where everything comes from.
class InstitutionScreen extends StatefulWidget {
  const InstitutionScreen({super.key, required this.institution});

  final Institution institution;

  @override
  State<InstitutionScreen> createState() => _InstitutionScreenState();
}

class _InstitutionScreenState extends State<InstitutionScreen> {
  Institution get _institution => widget.institution;

  Future<void> _toggleFollow() async {
    final alerts = AppScope.read(context).alerts;
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) =>
        messenger.showSnackBar(SnackBar(content: Text(text)));
    if (!alerts.supported) {
      say(
        tr(
          'News alerts work in the Android app.',
          'التنبيهات تعمل في تطبيق أندرويد.',
        ),
      );
      return;
    }
    try {
      final saved = alerts.alertFor(_institution.id);
      if (alerts.follows(_institution.id)) {
        await alerts.toggle(saved!.id, false);
        say(tr('Alerts paused.', 'أُوقفت التنبيهات.'));
        return;
      }
      if (!await alerts.permission(request: true)) {
        say(
          tr(
            'Allow notifications in Android settings first.',
            'اسمح بالإشعارات من إعدادات أندرويد أولًا.',
          ),
        );
        return;
      }
      await alerts.follow(_institution.id, _institution.displayName);
      say(tr('You will be told about new posts.', 'سيصلك تنبيه بكل خبر جديد.'));
    } on StateError catch (error) {
      say(error.message);
    } catch (_) {
      say(
        tr(
          'Could not update alerts. Try again.',
          'تعذر تحديث التنبيهات. حاول مرة أخرى.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final following = AppScope.of(context).alerts.follows(_institution.id);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_institution.displayName),
          actions: [
            IconButton(
              isSelected: following,
              tooltip: following
                  ? tr('Stop alerts', 'إيقاف التنبيهات')
                  : tr('Alert me about new posts', 'نبّهني بالأخبار الجديدة'),
              icon: Icon(
                following
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: following ? Brand.mint : null,
              ),
              onPressed: _toggleFollow,
            ),
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            labelColor: Brand.mint,
            unselectedLabelColor: Brand.muted,
            indicatorColor: Brand.mint,
            dividerColor: Brand.line,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            tabs: [
              Tab(text: tr('News', 'الأخبار')),
              Tab(text: tr('Info', 'المعلومات')),
              Tab(text: tr('Sources', 'المصادر')),
            ],
          ),
        ),
        body: PalmBackdrop(
          child: Column(
            children: [
              const StatusBanner(),
              Expanded(
                child: TabBarView(
                  children: [
                    _NewsTab(institution: _institution),
                    _InfoTab(institution: _institution),
                    _SourcesTab(institution: _institution),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// News: every post from every source, newest first
// ---------------------------------------------------------------------------

class _NewsTab extends StatefulWidget {
  const _NewsTab({required this.institution});

  final Institution institution;

  @override
  State<_NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<_NewsTab> with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  List<NewsPost> _posts = [];
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;
  int _request = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 900 &&
          _hasMore &&
          !_loading &&
          _error == null) {
        _load();
      }
    });
    _load(reset: true);
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
        widget.institution.id,
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

  Future<void> _open(NewsPost post) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => PostScreen(post: post)));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final Widget list;
    if (_posts.isEmpty && _error != null && !_loading) {
      list = ListView(
        children: [
          _Empty(
            icon: Icons.wifi_off_rounded,
            text: tr(
              'Could not load the news. Pull down to try again.',
              'تعذر تحميل الأخبار. اسحب للأسفل لإعادة المحاولة.',
            ),
          ),
        ],
      );
    } else if (_posts.isEmpty && (_loading || _hasMore)) {
      list = ListView.builder(
        itemCount: 3,
        itemBuilder: (_, _) => const PostSkeleton(),
      );
    } else if (_posts.isEmpty) {
      list = ListView(
        children: [
          _Empty(
            icon: Icons.inbox_outlined,
            text: tr('No news collected yet.', 'لم تُجمع أخبار بعد.'),
          ),
        ],
      );
    } else {
      list = ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 6, bottom: 24),
        itemCount: _posts.length + 1,
        itemBuilder: (_, index) => index == _posts.length
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: _loading
                      ? SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            semanticsLabel: tr(
                              'Loading more news',
                              'جارٍ تحميل المزيد',
                            ),
                          ),
                        )
                      : _error != null
                      ? TextButton(
                          onPressed: _load,
                          child: Text(
                            tr(
                              'Could not load more. Try again',
                              'تعذر تحميل المزيد. حاول مرة أخرى',
                            ),
                          ),
                        )
                      : Text(
                          _hasMore
                              ? ''
                              : tr("You're all caught up", 'لا جديد بعد هذا'),
                          style: const TextStyle(color: Brand.muted),
                        ),
                ),
              )
            : PostCard(post: _posts[index], onOpen: () => _open(_posts[index])),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      backgroundColor: Brand.surfaceHigh,
      child: list,
    );
  }
}

// ---------------------------------------------------------------------------
// Info: what people ask about most first (is study on, the coming dates, where to ask, the
// apps), then the numbers, each with its source
// ---------------------------------------------------------------------------

class _InfoTab extends StatefulWidget {
  const _InfoTab({required this.institution});

  final Institution institution;

  @override
  State<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<_InfoTab> with AutomaticKeepAliveClientMixin {
  List<InstitutionStat>? _stats;
  List<AppReview> _reviews = [];
  InfoPage _info = const InfoPage();
  bool _failed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final (stats, reviews, info) = await (
        UniNewsApi.stats(widget.institution.id),
        UniNewsApi.reviews(widget.institution.id),
        UniNewsApi.info(widget.institution.id),
      ).wait;
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _reviews = reviews;
        _info = info;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// One section of the page, or nothing when it has nothing to show.
  List<Widget> _section(String kind, List<InstitutionStat> stats) {
    final institution = widget.institution;
    final section = _info.section(kind);
    switch (kind) {
      case 'status':
        // Not looked for yet: say nothing rather than "none".
        if (section == null) return [];
        return [
          const SizedBox(height: 16),
          StudyStatus(items: _info.itemsOf('status'), section: section),
        ];
      case 'dates':
        final dates = upcomingDates(_info.itemsOf('dates'));
        if (dates.isEmpty) return [];
        return [
          const SizedBox(height: 16),
          ComingUp(items: dates, section: section),
        ];
      case 'help':
        final channels = _info.itemsOf('help');
        if (channels.isEmpty) return [];
        return [
          const SizedBox(height: 16),
          WhereToAsk(items: channels, section: section),
        ];
      case 'apps':
        final ratings = [
          for (final stat in stats)
            if (stat.unit == '/5') stat,
        ];
        if (ratings.isEmpty && _reviews.isEmpty) return [];
        return [
          const SizedBox(height: 16),
          InfoSectionTitle(tr('Its apps', 'تطبيقاتها')),
          for (final stat in ratings)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: StatTile(stat: stat),
            ),
          if (_reviews.isNotEmpty) ...[
            InfoSubtitle(
              tr('What its app users write', 'ماذا يكتب مستخدمو تطبيقاتها'),
              trailing: institution.reviewRating == null
                  ? null
                  : tr(
                      '${institution.reviewRating!.toStringAsFixed(1)} ★ from ${institution.reviewCount} reviews',
                      '${institution.reviewRating!.toStringAsFixed(1)} ★ من ${institution.reviewCount} مراجعة',
                    ),
            ),
            for (final review in _reviews) _ReviewTile(review: review),
          ],
        ];
      default: // numbers
        const groups = ['people', 'study', 'digital', 'research'];
        final numbers = [
          for (final stat in stats)
            if (stat.unit != '/5') stat,
        ];
        if (numbers.isEmpty) return [];
        return [
          const SizedBox(height: 16),
          InfoSectionTitle(tr('Numbers', 'أرقام')),
          for (final group in groups)
            if (numbers.any((stat) => stat.section == group)) ...[
              InfoSubtitle(sectionTitle(group)),
              for (final stat in numbers.where((stat) => stat.section == group))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: StatTile(stat: stat),
                ),
            ],
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final institution = widget.institution;
    final stats = _stats;
    return RefreshIndicator(
      onRefresh: _load,
      backgroundColor: Brand.surfaceHigh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Brand.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Brand.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InstitutionHeading(institution: institution, size: 56),
                if (institution.about case final about?) ...[
                  const SizedBox(height: 12),
                  Text(
                    about,
                    textDirection: directionOf(about),
                    style: const TextStyle(
                      color: Brand.inkSoft,
                      fontSize: 14.5,
                      height: 1.55,
                    ),
                  ),
                ],
                if (institution.websiteUrl case final website?) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => openLink(context, website),
                      icon: const Icon(Icons.language_rounded, size: 18),
                      label: Text(Uri.parse(website).host),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (stats != null && _info.ranked)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(
                tr(
                  'In the order people asked about them under its posts in the last 30 days.',
                  'بترتيب ما سأل عنه الناس أكثر تحت منشوراتها في آخر 30 يومًا.',
                ),
                style: const TextStyle(color: Brand.muted, fontSize: 11.5),
              ),
            ),
          if (stats == null && !_failed) const _Loading(),
          if (_failed)
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                tr(
                  'Could not load this page. Try again',
                  'تعذر تحميل الصفحة. حاول مرة أخرى',
                ),
              ),
            ),
          if (stats != null &&
              stats.isEmpty &&
              _reviews.isEmpty &&
              _info.items.isEmpty)
            _Empty(
              icon: Icons.insights_rounded,
              text: tr('Nothing collected yet.', 'لم يُجمع شيء بعد.'),
            ),
          if (stats != null)
            for (final kind in _info.order) ..._section(kind, stats),
          const SizedBox(height: 4),
          Text(
            tr(
              'Everything here shows where it comes from and opens it. Shaqra University\'s numbers come from its open data service; others from official reports and statements.',
              'لكل معلومة هنا مصدرها، وتفتحه عند الضغط. أرقام جامعة شقراء من خدمة البيانات المفتوحة لديها، والبقية من التقارير والتصريحات الرسمية.',
            ),
            style: const TextStyle(color: Brand.muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// A written review of one of the institution's apps, newest first. No author.
class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final AppReview review;

  @override
  Widget build(BuildContext context) {
    final title = review.title?.trim();
    return MergeSemantics(child: _tile(title));
  }

  Widget _tile(String? title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Brand.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Brand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${'★' * review.rating}${'☆' * (5 - review.rating)}',
                semanticsLabel: tr(
                  '${review.rating} of 5 stars',
                  '${review.rating} من 5 نجوم',
                ),
                style: const TextStyle(color: Brand.sand, fontSize: 13),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${review.appName} · ${shortDate(review.postedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Brand.muted, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (title != null && title.isNotEmpty && title != review.body.trim())
            Text(
              title,
              textDirection: directionOf(title),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
          Text(
            review.body,
            textDirection: directionOf(review.body),
            style: const TextStyle(
              color: Brand.inkSoft,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sources: every channel the protocol found, and whether it is collected yet
// ---------------------------------------------------------------------------

class _SourcesTab extends StatefulWidget {
  const _SourcesTab({required this.institution});

  final Institution institution;

  @override
  State<_SourcesTab> createState() => _SourcesTabState();
}

class _SourcesTabState extends State<_SourcesTab>
    with AutomaticKeepAliveClientMixin {
  List<NewsSource>? _sources;
  bool _failed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sources = await UniNewsApi.sources(widget.institution.id);
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sources = _sources;
    const roles = ['news', 'opinions', 'stats'];
    String roleTitle(String role) => switch (role) {
      'news' => tr('News', 'الأخبار'),
      'opinions' => tr('Opinions', 'الآراء'),
      _ => tr('Numbers', 'الأرقام'),
    };
    return RefreshIndicator(
      onRefresh: _load,
      backgroundColor: Brand.surfaceHigh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Text(
            tr(
              'Every official channel found with the WeshFatak source protocol: linked pages, hidden feeds, sub-accounts, official apps and open data.',
              'كل القنوات الرسمية التي وجدها بروتوكول وش فاتك للمصادر: الصفحات المرتبطة، والخلاصات المخفية، والحسابات الفرعية، والتطبيقات الرسمية، والبيانات المفتوحة.',
            ),
            style: const TextStyle(
              color: Brand.muted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (sources == null && !_failed) const _Loading(),
          if (_failed)
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                tr(
                  'Could not load sources. Try again',
                  'تعذر تحميل المصادر. حاول مرة أخرى',
                ),
              ),
            ),
          if (sources != null)
            for (final role in roles)
              if (sources.any((source) => source.role == role)) ...[
                const SizedBox(height: 16),
                _SectionTitle(roleTitle(role)),
                for (final source in sources.where(
                  (source) => source.role == role,
                ))
                  _SourceTile(source: source),
              ],
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source});

  final NewsSource source;

  @override
  Widget build(BuildContext context) {
    final (status, color) = switch (source.status) {
      'collected' => (tr('Collected', 'يُجمع'), Brand.mint),
      'manual' => (tr('By hand', 'يدوي'), Brand.sand),
      'planned' => (tr('Planned', 'مخطط'), Brand.muted),
      _ => (tr('Unavailable', 'غير متاح'), Brand.danger),
    };
    return MergeSemantics(
      child: Semantics(
        link: true,
        hint: tr('Opens this channel', 'يفتح هذه القناة'),
        child: _tile(context, status, color),
      ),
    );
  }

  Widget _tile(BuildContext context, String status, Color color) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    // With large text the status goes under the name instead of beside it.
    final large = largeText(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Brand.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Brand.line),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => openLink(context, source.url),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    platformIcon(source.platform),
                    color: Brand.inkSoft,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${platformLabelFor(source.platform)} · ${source.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      if (large) ...[const SizedBox(height: 4), pill],
                      const SizedBox(height: 2),
                      Text(
                        Uri.parse(source.url).host + Uri.parse(source.url).path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          color: Brand.muted,
                          fontSize: 12,
                        ),
                      ),
                      if (source.note case final note?) ...[
                        const SizedBox(height: 6),
                        Text(
                          note,
                          textDirection: directionOf(note),
                          style: const TextStyle(
                            color: Brand.inkSoft,
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!large) ...[const SizedBox(width: 8), pill],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String platformLabelFor(String platform) => switch (platform) {
  'rss' => 'RSS',
  'snapchat' => 'Snapchat',
  'linkedin' => 'LinkedIn',
  'open_data' => tr('Open data', 'بيانات مفتوحة'),
  'google_play' => 'Google Play',
  _ => platformLabel(platform),
};

// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Semantics(
      header: true,
      child: Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        semanticsLabel: tr('Loading', 'جارٍ التحميل'),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
    child: Column(
      children: [
        Icon(icon, size: 32, color: Brand.mint),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Brand.muted),
        ),
      ],
    ),
  );
}
