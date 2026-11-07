import 'package:flutter/material.dart';

import '../app_name.dart';
import '../brand.dart';
import '../data.dart';
import '../format.dart';
import '../l10n.dart';
import '../models.dart';
import '../widgets/mood.dart';
import '../widgets/status.dart';
import 'alerts_screen.dart';
import 'institution_screen.dart';

/// The home screen: every institution with its newest post and how people reacted to its news.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _refresher = GlobalKey<RefreshIndicatorState>();
  List<Institution>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await UniNewsApi.institutions();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _open(Institution institution) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => InstitutionScreen(institution: institution),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      body: PalmBackdrop(
        child: RefreshIndicator(
          key: _refresher,
          onRefresh: _load,
          edgeOffset: MediaQuery.paddingOf(context).top + 64,
          backgroundColor: Brand.surfaceHigh,
          child: CustomScrollView(
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
                  // Pulling down refreshes too, but a screen reader or a mouse cannot pull.
                  IconButton(
                    tooltip: tr('Refresh', 'تحديث'),
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => _refresher.currentState?.show(),
                  ),
                  IconButton(
                    tooltip: tr('News alerts', 'تنبيهات الأخبار'),
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AlertsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(1),
                  child: Divider(height: 1),
                ),
              ),
              const SliverToBoxAdapter(child: StatusBanner()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          tr('Institutions', 'الجهات'),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(
                          'News from every official channel and the Saudi press, what people said about each story, and the numbers behind each institution.',
                          'أخبار كل جهة من قنواتها الرسمية والصحافة السعودية، وماذا قال الناس عن كل خبر، وأرقامها.',
                        ),
                        style: const TextStyle(
                          color: Brand.muted,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (items == null && _error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Retry(onRetry: _load),
                )
              else if (items == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: tr('Loading', 'جارٍ التحميل'),
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (_, index) => InstitutionCard(
                    institution: items[index],
                    onOpen: () => _open(items[index]),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  // The name and tagline sit in a bar of fixed height, so they grow with the phone's text size only
  // up to 130%; everything below the bar grows fully.
  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.3,
    child: Row(
      children: [
        const ExcludeSemantics(child: UniLogo(size: 38)),
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
                tr(
                  'WHAT PEOPLE SAY ABOUT EDUCATION',
                  'ماذا يقول الناس عن التعليم',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                semanticsLabel: tr(
                  'What people say about education',
                  'ماذا يقول الناس عن التعليم',
                ),
                style: const TextStyle(
                  color: Brand.sand,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// An institution on the home screen: its name, its newest post, how people reacted to its
/// news and what the app holds about it.
class InstitutionCard extends StatelessWidget {
  const InstitutionCard({
    super.key,
    required this.institution,
    required this.onOpen,
  });

  final Institution institution;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final mood = institution.emotions;
    final latest = institution.latestBody
        ?.replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // A screen reader reads the whole card as one item that opens the institution's page.
    return MergeSemantics(
      child: Semantics(
        button: true,
        hint: tr(
          'Opens its news, info and sources',
          'يفتح أخبارها ومعلوماتها ومصادرها',
        ),
        child: _card(mood, latest),
      ),
    );
  }

  Widget _card(Map<String, int> mood, String? latest) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InstitutionHeading(institution: institution),
                if (latest != null && latest.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    institution.lastPostAt == null
                        ? tr('Latest news', 'آخر الأخبار')
                        : '${tr('Latest news', 'آخر الأخبار')} · ${shortDate(institution.lastPostAt!)}',
                    style: const TextStyle(
                      color: Brand.mint,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    latest,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: directionOf(latest),
                    style: const TextStyle(
                      color: Brand.ink,
                      fontSize: 14.5,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (mood.isEmpty)
                  Text(
                    tr(
                      'No replies to its news collected yet.',
                      'لم تُجمع ردود على أخبارها بعد.',
                    ),
                    style: const TextStyle(color: Brand.muted, fontSize: 13),
                  )
                else ...[
                  Text(
                    tr('Replies to its news', 'الردود على أخبارها'),
                    style: const TextStyle(color: Brand.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  MoodStrip(counts: mood, height: 8),
                  const SizedBox(height: 6),
                  ExcludeSemantics(
                    child: Text(
                      moodHeadline(mood),
                      style: const TextStyle(
                        color: Brand.inkSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _Count(
                      Icons.newspaper_rounded,
                      tr(
                        '${institution.postCount} posts',
                        '${institution.postCount} خبرًا',
                      ),
                    ),
                    _Count(
                      Icons.forum_outlined,
                      tr(
                        '${institution.replyCount} replies',
                        '${institution.replyCount} ردًا',
                      ),
                    ),
                    _Count(
                      Icons.insights_rounded,
                      tr(
                        '${institution.statCount} numbers',
                        '${institution.statCount} رقمًا',
                      ),
                    ),
                    _Count(
                      Icons.hub_outlined,
                      tr(
                        '${institution.sourceCount} sources',
                        '${institution.sourceCount} مصدرًا',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo, name in both languages, kind, city and founding year.
class InstitutionHeading extends StatelessWidget {
  const InstitutionHeading({
    super.key,
    required this.institution,
    this.size = 52,
  });

  final Institution institution;
  final double size;

  @override
  Widget build(BuildContext context) {
    final details = [
      institution.kindLabel,
      ?institution.city,
      if (institution.foundedYear != null)
        tr(
          'since ${institution.foundedYear}',
          'منذ ${institution.foundedYear}',
        ),
    ].join(' · ');
    return Row(
      children: [
        SourceAvatar(url: institution.logoUrl, size: size),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                institution.displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (institution.otherName case final other?)
                Text(
                  other,
                  style: const TextStyle(color: Brand.inkSoft, fontSize: 13),
                ),
              const SizedBox(height: 2),
              Text(
                details,
                style: const TextStyle(color: Brand.muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: Brand.muted),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
    ],
  );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.wifi_off_rounded, size: 36, color: Brand.mint),
        const SizedBox(height: 14),
        Text(
          tr('Could not load the institutions', 'تعذر تحميل الجهات'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          tr(
            'Check your internet connection and try again.',
            'تحقق من اتصالك بالإنترنت وحاول مرة أخرى.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Brand.muted),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onRetry,
          child: Text(tr('Try again', 'حاول مرة أخرى')),
        ),
      ],
    ),
  );
}
