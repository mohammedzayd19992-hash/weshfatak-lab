import 'package:flutter/widgets.dart';

String appNameFor(Locale locale) =>
    locale.languageCode == 'ar' ? 'وش فاتك' : 'WeshFatak';

String appName(BuildContext context) =>
    appNameFor(WidgetsBinding.instance.platformDispatcher.locale);
