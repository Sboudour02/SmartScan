import 'package:flutter/material.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  void setLocale(Locale tempLocale) {
    if (!['en', 'ar', 'fr'].contains(tempLocale.languageCode)) return;
    _locale = tempLocale;
    notifyListeners();
  }
}
