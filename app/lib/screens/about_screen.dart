import 'package:flutter/material.dart';

import '../app_name.dart';
import '../brand.dart';
import '../config.dart';
import '../data.dart';
import '../format.dart';
import '../l10n.dart';
import '../widgets/info.dart';
import '../widgets/prototype.dart';

/// What WeshFatak is, that it is a prototype and how old its data is, where everything comes from,
/// what AI does, what stays on the phone, and where to send feedback.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stage = isPrototype
        ? tr('prototype', 'نموذج أولي')
        : tr('release', 'إصدار عام');
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('About ${appName(context)}', 'عن ${appName(context)}')),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: PalmBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(
              children: [
                const ExcludeSemantics(child: UniLogo(size: 52)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appName(context),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        tr(
                          'What people say about education',
                          'ماذا يقول الناس عن التعليم',
                        ),
                        style: const TextStyle(color: Brand.sand, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr(
                          'Version $appVersion · $stage',
                          'الإصدار $appVersion · $stage',
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
            _Part(
              title: tr('What it is', 'ما هو'),
              text: tr(
                'Everything an education institution announces, in one place: its news from every official channel and the Saudi press, what people said under each story, and answers to what people ask most: is study on, which dates are coming, and where to ask.',
                'كل ما تعلنه جهة التعليم في مكان واحد: أخبارها من كل قنواتها الرسمية والصحافة السعودية، وماذا قال الناس تحت كل خبر، وإجابات أكثر ما يسأل عنه الناس: هل الدراسة قائمة، وما المواعيد القادمة، وأين تسأل.',
              ),
            ),
            if (isPrototype)
              ValueListenableBuilder<DateTime?>(
                valueListenable: UniNewsApi.collectedAt,
                builder: (context, at, _) {
                  final data = collectionLine(at, demo: UniNewsApi.demoMode);
                  return _Part(
                    title: tr('A prototype', 'نموذج أولي'),
                    text: [
                      tr(
                        'A student project to test the idea. It is not an official service of the Ministry of Education or of any university.',
                        'مشروع طلابي لاختبار الفكرة، وليس خدمة رسمية لوزارة التعليم أو لأي جامعة.',
                      ),
                      ?data,
                    ].join('\n\n'),
                    highlight: dataIsOld(at),
                  );
                },
              ),
            _Part(
              title: tr('Where it comes from', 'من أين تأتي المعلومات'),
              text: tr(
                "The institutions' own X accounts, websites, feeds and YouTube channels, SPA and the Saudi papers, their apps' store pages and open data. Every story, number and date links to where it came from.",
                'من حسابات الجهات نفسها في إكس ومواقعها وخلاصاتها وقنواتها في يوتيوب، ومن واس والصحف السعودية، وصفحات تطبيقاتها في المتاجر وبياناتها المفتوحة. لكل خبر ورقم وموعد رابط إلى مصدره.',
              ),
            ),
            _Part(
              title: tr('What AI does', 'دور الذكاء الاصطناعي'),
              text: tr(
                'One job: it reads the public replies under a story and writes the faces and the "What people said" summary. Numbers, dates and study announcements never come from AI. A summary can misread the replies, so every story page has "Report a mistake".',
                'مهمة واحدة: يقرأ الردود العامة تحت الخبر ويكتب الوجوه وملخص «ماذا قال الناس». أما الأرقام والمواعيد وإعلانات الدراسة فلا تأتي من الذكاء الاصطناعي أبدًا. وقد يخطئ الملخص في فهم الردود، لذلك في صفحة كل خبر «الإبلاغ عن خطأ».',
              ),
            ),
            _Part(
              title: tr('Your privacy', 'خصوصيتك'),
              text: tr(
                'No accounts. The app only reads public news and sends nothing about you. The institutions you follow and copies of the pages you opened stay on your phone. Replies are kept without who wrote them.',
                'لا حسابات. التطبيق يقرأ الأخبار العامة فقط ولا يرسل شيئًا عنك. الجهات التي تتابعها ونسخ الصفحات التي فتحتها تبقى على هاتفك. وتُحفظ الردود دون أسماء كاتبيها.',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: () => openLink(
                context,
                feedbackLink(
                  title: tr(
                    'Feedback on WeshFatak $appVersion',
                    'ملاحظة على وش فاتك $appVersion',
                  ),
                ),
              ),
              icon: const Icon(Icons.rate_review_outlined),
              label: Text(
                tr(
                  'Send feedback or report a mistake',
                  'أرسل ملاحظة أو أبلغ عن خطأ',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => openLink(context, sourceCodeUrl),
              icon: const Icon(Icons.code_rounded),
              label: Text(
                tr('Source code on GitHub', 'الشفرة المصدرية على GitHub'),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One part of the page: a heading and its text.
class _Part extends StatelessWidget {
  const _Part({
    required this.title,
    required this.text,
    this.highlight = false,
  });

  final String title;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 14),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    decoration: BoxDecoration(
      color: Brand.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: highlight ? Brand.sand.withValues(alpha: 0.55) : Brand.line,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          style: const TextStyle(
            color: Brand.inkSoft,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}
