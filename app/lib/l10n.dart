import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The app's language: Arabic on Arabic phones, English otherwise.
/// In the browser, `?lang=ar` or `?lang=en` picks one (for demos).
Locale get appLocale {
  final asked = kIsWeb ? Uri.base.queryParameters['lang'] : null;
  final code =
      asked ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  return code == 'ar' ? const Locale('ar') : const Locale('en');
}

bool get isArabic => appLocale.languageCode == 'ar';

/// The English or the Arabic text, in the app's language.
String tr(String en, String ar) => isArabic ? ar : en;
