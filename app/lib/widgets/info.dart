import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../brand.dart';
import '../format.dart';
import '../l10n.dart';
import '../models.dart';

// ---------------------------------------------------------------------------
// Days and times in words (plain functions, so they can be tested on their own)
// ---------------------------------------------------------------------------

/// Whole calendar days from [today] to [day]: 0 today, 1 tomorrow, -1 yesterday.
int daysBetween(DateTime today, DateTime day) => DateTime.utc(
  day.year,
  day.month,
  day.day,
).difference(DateTime.utc(today.year, today.month, today.day)).inDays;

/// An Arabic count with its noun in the right form: يوم، يومين، 3 أيام، 11 يومًا.
String _arabicCount(int n, String one, String two, String few, String many) =>
    switch (n) {
      1 => one,
      2 => two,
      >= 3 && <= 10 => '$n $few',
      _ => '$n $many',
    };

/// "Today", "Tomorrow", "In 16 days", or "Now" while it lasts.
String countdown(InfoItem item, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final start = daysBetween(today, item.startsOn!);
  final end = daysBetween(today, item.lastDay!);
  if (start <= 0 && end >= 0) {
    return start == 0 && end == 0 ? tr('Today', 'اليوم') : tr('Now', 'الآن');
  }
  if (start == 1) return tr('Tomorrow', 'غدًا');
  return tr(
    'In $start days',
    'بعد ${_arabicCount(start, 'يوم', 'يومين', 'أيام', 'يومًا')}',
  );
}

const _weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _weekdaysAr = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

/// "Fri Nov 20" (Arabic: "الجمعة 20/11").
String dayLabel(DateTime day, {DateTime? now}) =>
    '${(isArabic ? _weekdaysAr : _weekdaysEn)[day.weekday - 1]} ${shortDate(day, now: now)}';

/// The day it starts, and the day it ends when that is another day.
String dateRange(InfoItem item, {DateTime? now}) {
  final start = dayLabel(item.startsOn!, now: now);
  final end = item.endsOn;
  if (end == null || daysBetween(item.startsOn!, end) == 0) return start;
  return '$start – ${dayLabel(end, now: now)}';
}

/// "5 min ago", "3 h ago", "2 days ago" (Arabic: "قبل 5 دقائق", "قبل 3 ساعات", "قبل يومين").
String timeAgo(DateTime time, {DateTime? now}) {
  final passed = (now ?? DateTime.now()).difference(time);
  if (passed.inMinutes < 60) {
    final minutes = math.max(1, passed.inMinutes);
    return tr(
      '$minutes min ago',
      'قبل ${_arabicCount(minutes, 'دقيقة', 'دقيقتين', 'دقائق', 'دقيقة')}',
    );
  }
  if (passed.inHours < 24) {
    final hours = passed.inHours;
    return tr(
      '$hours h ago',
      'قبل ${_arabicCount(hours, 'ساعة', 'ساعتين', 'ساعات', 'ساعة')}',
    );
  }
  final days = passed.inDays;
  return tr(
    days == 1 ? '1 day ago' : '$days days ago',
    'قبل ${_arabicCount(days, 'يوم', 'يومين', 'أيام', 'يومًا')}',
  );
}

/// The collectors run every 2.5 hours when they are on, so data a day old means they are off.
const dataGetsOldAfter = Duration(hours: 24);

/// Whether data collected at [at] is too old to be taken as current.
bool dataIsOld(DateTime? at, {DateTime? now}) =>
    at != null && (now ?? DateTime.now()).difference(at) > dataGetsOldAfter;

/// "14:05" today, else "2/11 21:30".
String clock(DateTime time, {DateTime? now}) {
  final hours = time.hour.toString().padLeft(2, '0');
  final minutes = time.minute.toString().padLeft(2, '0');
  return daysBetween(now ?? DateTime.now(), time) == 0
      ? '$hours:$minutes'
      : '${shortDate(time, now: now)} $hours:$minutes';
}

/// What a channel's link shows: the number, the address, or the site.
String linkLabel(String link) => link.startsWith('tel:')
    ? link.substring(4)
    : link.startsWith('mailto:')
    ? link.substring(7)
    : Uri.parse(link).host;

IconData linkIcon(String link) => link.startsWith('tel:')
    ? Icons.call_rounded
    : link.startsWith('mailto:')
    ? Icons.mail_outline_rounded
    : Icons.open_in_new_rounded;

/// The dates that have not ended yet, soonest first.
List<InfoItem> upcomingDates(List<InfoItem> items, {DateTime? now}) {
  final today = now ?? DateTime.now();
  return [
    for (final item in items)
      if (item.startsOn != null && daysBetween(today, item.lastDay!) >= 0) item,
  ]..sort((a, b) => a.startsOn!.compareTo(b.startsOn!));
}

// ---------------------------------------------------------------------------
// The sections
// ---------------------------------------------------------------------------

BoxDecoration _box({Color? border}) => BoxDecoration(
  color: Brand.surface.withValues(alpha: 0.94),
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: border ?? Brand.line),
);

/// A section's title, with a short line beside it and a note under it.
class InfoSectionTitle extends StatelessWidget {
  const InfoSectionTitle(this.title, {super.key, this.trailing, this.note});

  final String title;
  final String? trailing;
  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  trailing!,
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: Brand.muted, fontSize: 12.5),
                ),
              ),
            ],
          ],
        ),
        if (note case final note? when note.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            note,
            textDirection: directionOf(note),
            style: const TextStyle(
              color: Brand.muted,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ],
    ),
  );
}

/// A smaller title inside a section ("What its app users write", "People").
class InfoSubtitle extends StatelessWidget {
  const InfoSubtitle(this.title, {super.key, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(
                color: Brand.inkSoft,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              trailing!,
              textAlign: TextAlign.end,
              style: const TextStyle(color: Brand.muted, fontSize: 12.5),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Is study suspended, online or back in person? The newest official word about it from the
/// last week, or a plain line saying there was none. When nobody has looked for a day (the
/// collectors are off), it says since when first, so an old answer is not taken for today's.
class StudyStatus extends StatelessWidget {
  const StudyStatus({super.key, required this.items, this.section, this.now});

  final List<InfoItem> items;
  final InfoSection? section;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final checked = section?.checkedAt;
    final old = dataIsOld(checked, now: now);
    final day = checked == null ? '' : dayLabel(checked, now: now);
    final ago = checked == null ? '' : timeAgo(checked, now: now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoSectionTitle(
          tr('Study: in person or online?', 'الدراسة: حضوري أم عن بعد؟'),
          trailing: checked == null || old
              ? null
              : tr(
                  'Checked ${clock(checked, now: now)}',
                  'آخر تحقق ${clock(checked, now: now)}',
                ),
        ),
        if (old)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Brand.sand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Brand.sand.withValues(alpha: 0.55)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.history_rounded, color: Brand.sand, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr(
                      'Not checked since $day, $ago, so this may be out of date. Decisions on study can change from one day to the next.',
                      'لم يُتحقق منذ $day، $ago، فقد لا يكون هذا محدّثًا. قرارات الدراسة قد تتغير بين يوم وآخر.',
                    ),
                    style: const TextStyle(
                      color: Brand.ink,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _box(),
            child: Row(
              children: [
                const Icon(
                  Icons.event_available_rounded,
                  color: Brand.mint,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        old
                            ? tr(
                                'No announcement in the 7 days before $day about suspending study or moving it online.',
                                'لا إعلان في الأيام السبعة التي سبقت $day عن تعليق الدراسة أو تحويلها عن بعد.',
                              )
                            : tr(
                                'No announcement in the last 7 days about suspending study or moving it online.',
                                'لا إعلان في آخر 7 أيام عن تعليق الدراسة أو تحويلها عن بعد.',
                              ),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(
                          'From its official channels and the Saudi press.',
                          'من قنواتها الرسمية والصحف السعودية.',
                        ),
                        style: const TextStyle(
                          color: Brand.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          for (final item in items) _Announcement(item: item, now: now),
      ],
    );
  }
}

/// One post or report about study, newest first. The last two days' stand out.
class _Announcement extends StatelessWidget {
  const _Announcement({required this.item, this.now});

  final InfoItem item;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final published = item.publishedAt;
    final fresh =
        published != null &&
        (now ?? DateTime.now()).difference(published).inHours < 48;
    return MergeSemantics(
      child: Semantics(
        link: true,
        hint: tr('Opens the announcement', 'يفتح الإعلان'),
        child: _card(context, published, fresh),
      ),
    );
  }

  Widget _card(BuildContext context, DateTime? published, bool fresh) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: _box(
        border: fresh ? Brand.sand.withValues(alpha: 0.55) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => openLink(context, item.link ?? item.sourceUrl),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.title,
                  textDirection: directionOf(item.title),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.newspaper_rounded,
                      size: 15,
                      color: Brand.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        published == null
                            ? item.sourceName
                            // In English a left-to-right mark after an Arabic outlet's name
                            // keeps "3 days ago" whole instead of "3 · Sabq days ago".
                            : '${item.sourceName}${isArabic ? '' : '\u200E'} · ${timeAgo(published, now: now)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Brand.muted,
                          fontSize: 12.5,
                        ),
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

/// The coming dates of the academic calendar, each counting down, with where they come from.
class ComingUp extends StatefulWidget {
  const ComingUp({super.key, required this.items, this.section, this.now});

  final List<InfoItem> items; // only dates that have not ended (upcomingDates)
  final InfoSection? section;
  final DateTime? now;

  static const shownFirst = 4;

  @override
  State<ComingUp> createState() => _ComingUpState();
}

class _ComingUpState extends State<ComingUp> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final shown = _all ? items : items.take(ComingUp.shownFirst).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoSectionTitle(
          tr('Coming up', 'المواعيد القادمة'),
          note: widget.section?.note,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: _box(),
          child: Column(
            children: [
              for (final (index, item) in shown.indexed) ...[
                if (index > 0) const Divider(height: 1, color: Brand.line),
                _DateRow(item: item, now: widget.now),
              ],
            ],
          ),
        ),
        if (items.length > ComingUp.shownFirst)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() => _all = !_all),
              child: Text(
                _all
                    ? tr('Show fewer', 'عرض أقل')
                    : tr(
                        'All ${items.length} dates',
                        'كل المواعيد (${items.length})',
                      ),
              ),
            ),
          ),
        _Sources(items: shown),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.item, this.now});

  final InfoItem item;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final today = now ?? DateTime.now();
    final going = daysBetween(today, item.startsOn!) <= 0;
    final chip = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 78),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: going
              ? Brand.green.withValues(alpha: 0.28)
              : Brand.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: going ? Brand.green : Brand.line),
        ),
        child: Text(
          countdown(item, now: today),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: going ? Brand.mint : Brand.sand,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          textDirection: directionOf(item.title),
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          dateRange(item, now: today),
          style: const TextStyle(color: Brand.muted, fontSize: 12.5),
        ),
      ],
    );
    // With large text the countdown goes above the date instead of beside it.
    if (largeText(context)) {
      return MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [chip, const SizedBox(height: 6), words],
          ),
        ),
      );
    }
    // Read as one item: "In 16 days, autumn break, Fri Nov 20 – Sat Nov 28".
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            chip,
            const SizedBox(width: 12),
            Expanded(child: words),
          ],
        ),
      ),
    );
  }
}

/// The official channels that answer: a ticket, a phone number, an email address.
class WhereToAsk extends StatelessWidget {
  const WhereToAsk({super.key, required this.items, this.section});

  final List<InfoItem> items;
  final InfoSection? section;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InfoSectionTitle(tr('Where to ask', 'أين تسأل؟'), note: section?.note),
      for (final item in items) _Channel(item: item),
      _Sources(items: items),
    ],
  );
}

class _Channel extends StatelessWidget {
  const _Channel({required this.item});

  final InfoItem item;

  @override
  Widget build(BuildContext context) {
    final link = item.link;
    return MergeSemantics(
      child: Semantics(
        link: link != null,
        hint: link == null
            ? null
            : link.startsWith('tel:')
            ? tr('Calls this number', 'يتصل بهذا الرقم')
            : link.startsWith('mailto:')
            ? tr('Writes an email', 'يكتب رسالة بريد')
            : tr('Opens the page', 'يفتح الصفحة'),
        child: _card(context, link),
      ),
    );
  }

  Widget _card(BuildContext context, String? link) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: _box(),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: link == null ? null : () => openLink(context, link),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    link == null ? Icons.info_outline_rounded : linkIcon(link),
                    color: Brand.mint,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        textDirection: directionOf(item.title),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (item.detail case final detail?) ...[
                        const SizedBox(height: 3),
                        Text(
                          detail,
                          textDirection: directionOf(detail),
                          style: const TextStyle(
                            color: Brand.inkSoft,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                      if (link != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          linkLabel(link),
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            color: Brand.mint,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Where a section's lines come from, each source once, opening it.
class _Sources extends StatelessWidget {
  const _Sources({required this.items});

  final List<InfoItem> items;

  @override
  Widget build(BuildContext context) {
    final sources = <String, String>{};
    for (final item in items) {
      sources.putIfAbsent(item.sourceUrl, () => item.sourceName);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final MapEntry(key: url, value: name) in sources.entries)
          TextButton.icon(
            onPressed: () => openLink(context, url),
            icon: const Icon(Icons.link_rounded, size: 16),
            label: Text(
              '${tr('Source', 'المصدر')}: $name',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            style: TextButton.styleFrom(
              foregroundColor: Brand.muted,
              textStyle: const TextStyle(fontSize: 12),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(48, 48),
            ),
          ),
      ],
    );
  }
}
