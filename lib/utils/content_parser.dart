import 'package:flutter/material.dart';

class ContentParser {
  static final RegExp _urlRegex = RegExp(
      r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
      caseSensitive: false);
  static final RegExp _deepLinkRegex = RegExp(
      r'^(wa\.me|t\.me|instagram\.com|twitter\.com|x\.com|facebook\.com)\/.*$',
      caseSensitive: false);
  static final RegExp _schemeRegex = RegExp(r'^(mailto|tel|sms|geo):', caseSensitive: false);
  static final RegExp _hasSchemeRegex = RegExp(r'^([a-zA-Z][a-zA-Z0-9\+\-\.]*:)', caseSensitive: false);

  /// Checks if the provided content is a URL or has a recognized URI scheme.
  static bool isUrl(String? content) {
    if (content == null) return false;
    return _urlRegex.hasMatch(content) ||
           _deepLinkRegex.hasMatch(content) ||
           _schemeRegex.hasMatch(content);
  }

  /// Checks if the content starts with any URI scheme (e.g., https:, mailto:, tel:).
  static bool hasScheme(String? content) {
    if (content == null) return false;
    return _hasSchemeRegex.hasMatch(content);
  }
}
