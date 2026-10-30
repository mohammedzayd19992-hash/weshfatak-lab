import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';

import 'brand.dart';

/// "Oct 15", with the year added for older posts.
String shortDate(DateTime time, {DateTime? now}) =>
    time.year == (now ?? DateTime.now()).year
    ? intl.DateFormat('MMM d').format(time)
    : intl.DateFormat('MMM d, y').format(time);

final _rtlLetter = RegExp(r'[֐-׿؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]');
final _anyLetter = RegExp(r'[A-Za-zÀ-ɏ֐-׿؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]');

/// Right-to-left when the first letter is Arabic (or Hebrew), else left-to-right.
TextDirection directionOf(String text) {
  final first = _anyLetter.firstMatch(text)?.group(0);
  return first != null && _rtlLetter.hasMatch(first)
      ? TextDirection.rtl
      : TextDirection.ltr;
}

Future<void> openLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {}
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text('The link could not be opened.')),
    );
  }
}

/// Post text with tappable #hashtags (opened on X) and links,
/// laid out in the text's own direction.
class LinkedText extends StatefulWidget {
  const LinkedText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<LinkedText> {
  static final _pattern = RegExp(
    r'#[\p{L}\p{N}_]+|https?://[^\s]+',
    unicode: true,
  );
  static const _linkStyle = TextStyle(
    color: Brand.mint,
    fontWeight: FontWeight.w600,
  );
  final _recognizers = <TapGestureRecognizer>[];
  late List<InlineSpan> _spans;

  @override
  void initState() {
    super.initState();
    _spans = _build();
  }

  @override
  void didUpdateWidget(LinkedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _spans = _build();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  List<InlineSpan> _build() {
    _disposeRecognizers();
    final text = widget.text;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in _pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      final value = match.group(0)!;
      final url = value.startsWith('#')
          ? 'https://x.com/hashtag/${Uri.encodeComponent(value.substring(1))}'
          : value;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => openLink(context, url);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(text: value, style: _linkStyle, recognizer: recognizer),
      );
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(style: widget.style, children: _spans),
    textDirection: directionOf(widget.text),
  );
}
