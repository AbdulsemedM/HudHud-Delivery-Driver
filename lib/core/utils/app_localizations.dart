import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ar'),
  ];

  static const String translationsPath = 'assets/lang';
  static const Locale fallbackLocale = Locale('en');
  
  static String translate(String key, {Map<String, String>? args}) {
    return tr(key, namedArgs: args);
  }
  
  static Future<void> setLocale(BuildContext context, Locale locale) async {
    await context.setLocale(locale);
  }
  
  static Locale currentLocale(BuildContext context) {
    return context.locale;
  }
  
  static bool isRtl(BuildContext context) {
    return context.locale.languageCode == 'ar';
  }
}