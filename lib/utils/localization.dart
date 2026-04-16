import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';

class AppLocalizations {
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_name': 'SmartScan',
      'qr_generator': 'QR Generator',
      'barcode_generator': 'Barcode Generator',
      'scanner': 'Scanner',
      'settings': 'Settings',
      'language': 'Language',
      'batch_generation': 'Batch Generation',
      'history': 'History',
      'history_empty': 'No history yet.',
      'choose_format': 'Choose Format',
      'export': 'Export',
      'share': 'Share',
      'save': 'Save',
      'content_type': 'Content Type',
      'pick_logo': 'Pick Logo',
      'colors': 'Colors & Shapes',
      'dark_mode': 'Dark Mode',
    },
    'ar': {
      'app_name': 'سمارت سكان',
      'qr_generator': 'إنشاء QR',
      'barcode_generator': 'إنشاء باركود',
      'scanner': 'الماسح الضوئي',
      'settings': 'الإعدادات',
      'language': 'اللغة',
      'batch_generation': 'توليد بالجملة',
      'history': 'السجل',
      'history_empty': 'لا يوجد سجل حتى الآن.',
      'choose_format': 'اختر الصيغة',
      'export': 'تصدير',
      'share': 'مشاركة',
      'save': 'حفظ',
      'content_type': 'نوع المحتوى',
      'pick_logo': 'اختيار شعار',
      'colors': 'الألوان والأشكال',
      'dark_mode': 'الوضع الليلي',
    },
    'fr': {
      'app_name': 'SmartScan',
      'qr_generator': 'Générer QR',
      'barcode_generator': 'Générer Code-barres',
      'scanner': 'Scanner',
      'settings': 'Paramètres',
      'language': 'Langue',
      'batch_generation': 'Génération par Lot',
      'history': 'Historique',
      'history_empty': 'Aucun historique.',
      'choose_format': 'Choisissez le Format',
      'export': 'Exporter',
      'share': 'Partager',
      'save': 'Enregistrer',
      'content_type': 'Type de contenu',
      'pick_logo': 'Choisir Logo',
      'colors': 'Couleurs et Formes',
      'dark_mode': 'Mode Sombre',
    },
  };

  static String of(BuildContext context, String key) {
    final locale = Provider.of<LocaleProvider>(context).locale.languageCode;
    return _localizedValues[locale]?[key] ?? key;
  }
}
