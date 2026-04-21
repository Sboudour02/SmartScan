import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  static const String _key = 'app_locale';

  Locale get locale => _locale;

  LocaleProvider() {
    _loadLocale();
  }

  Future<void> setLocale(Locale tempLocale) async {
    if (!['en', 'ar', 'fr'].contains(tempLocale.languageCode)) return;
    _locale = tempLocale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, tempLocale.languageCode);
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final String? langCode = prefs.getString(_key);
    if (langCode != null && ['en', 'ar', 'fr'].contains(langCode)) {
      _locale = Locale(langCode);
      notifyListeners();
    }
  }
}
