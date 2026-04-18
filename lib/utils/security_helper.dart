import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 🛡️ AntiGravity Security Protocol — Content Analysis Engine
// Protected App: SmartScan v1.0
// ═══════════════════════════════════════════════════════════════════════════════

/// Security level classification for the Decision Matrix
enum SecurityLevel {
  safe,       // ✅ Allow — content is completely clean
  sanitized,  // 🧹 Fixed — malicious parts removed, safe version passed through
  warning,    // ⚠️ Warn — suspicious but might be legitimate, ask user
  blocked,    // 🚫 Block — definite threat, kill immediately
}

/// Result of a security analysis
class SecurityResult {
  final SecurityLevel level;
  final String messageEn;
  final String messageAr;
  final String messageFr;
  final String? sanitizedContent;
  final String? originalContent;
  final String? threatType;

  const SecurityResult({
    required this.level,
    required this.messageEn,
    this.messageAr = '',
    this.messageFr = '',
    this.sanitizedContent,
    this.originalContent,
    this.threatType,
  });

  /// Get localized message
  String getMessage(String langCode) {
    switch (langCode) {
      case 'ar':
        return messageAr.isNotEmpty ? messageAr : messageEn;
      case 'fr':
        return messageFr.isNotEmpty ? messageFr : messageEn;
      default:
        return messageEn;
    }
  }
}

class SecurityHelper {
  // ─────────────────────────────────────────────────────────────────────────────
  // Configuration Constants
  // ─────────────────────────────────────────────────────────────────────────────

  /// Maximum input length to prevent DoS/Buffer Overflow attacks
  static const int maxInputLength = 4096;

  /// Maximum batch file entries
  static const int maxBatchEntries = 500;

  /// Dangerous URL schemes that MUST be blocked immediately
  static const List<String> _blockedSchemes = [
    'javascript:',
    'data:',
    'vbscript:',
    'file://',
    'telnet://',
    'cmd:',
    'powershell:',
  ];

  /// Suspicious URL schemes that trigger a warning
  static const List<String> _warnSchemes = [
    'ftp://',
    'ssh://',
    'smb://',
  ];

  /// Known phishing domain patterns
  static const List<String> _suspiciousDomainPatterns = [
    'login-',
    'signin-',
    'account-verify',
    'secure-update',
    'banking-',
    'paypal-confirm',
    'apple-id-',
    'microsoft-verify',
    'google-security',
    'facebook-auth',
    '.tk',
    '.ml',
    '.ga',
    '.cf',
    '.gq',
  ];

  /// Code injection patterns — these are attacks targeting the app itself
  static const List<String> _injectionPatterns = [
    '<script',
    '</script>',
    'javascript:',
    'onerror=',
    'onload=',
    'onclick=',
    'onmouseover=',
    'onfocus=',
    'eval(',
    'document.cookie',
    'document.write',
    'window.location',
    'String.fromCharCode',
    'DROP TABLE',
    'DELETE FROM',
    'INSERT INTO',
    'UNION SELECT',
    'UPDATE SET',
    "'; --",
    '"; --',
    '/* ',
    ' */',
    'exec(',
    'xp_cmdshell',
  ];

  /// Sensitive data patterns (credit cards, SSN, passwords)
  static final List<RegExp> _sensitivePatterns = [
    // Visa
    RegExp(r'\b4[0-9]{12}(?:[0-9]{3})?\b'),
    // MasterCard
    RegExp(r'\b5[1-5][0-9]{14}\b'),
    // American Express
    RegExp(r'\b3[47][0-9]{13}\b'),
    // Discover
    RegExp(r'\b6(?:011|5[0-9]{2})[0-9]{12}\b'),
    // Social Security Number (US)
    RegExp(r'\b\d{3}-\d{2}-\d{4}\b'),
    // Password patterns
    RegExp(r'(?:password|passwd|pwd|pass)\s*[:=]\s*\S+', caseSensitive: false),
    // API Keys / Tokens (long hex or base64 strings)
    RegExp(r'\b(?:api[_-]?key|token|secret)\s*[:=]\s*[A-Za-z0-9+/=_-]{20,}\b', caseSensitive: false),
  ];

  // ─────────────────────────────────────────────────────────────────────────────
  // 🎯 Main Entry Point — Decision Matrix
  // ─────────────────────────────────────────────────────────────────────────────

  /// Analyze ANY content entering the app.
  /// This is the central decision engine.
  static SecurityResult analyzeContent(String content) {
    if (content.trim().isEmpty) {
      return const SecurityResult(
        level: SecurityLevel.safe,
        messageEn: 'Empty content',
      );
    }

    // ── Step 1: DoS Prevention (oversized input) ──
    if (content.length > maxInputLength) {
      return SecurityResult(
        level: SecurityLevel.blocked,
        messageEn: 'Input blocked: Content is too long (${content.length} characters). This may be a denial-of-service attempt.',
        messageAr: 'تم الحظر: المحتوى طويل جداً (${content.length} حرف). قد يكون هذا محاولة إغراق.',
        messageFr: 'Bloqué : Le contenu est trop long (${content.length} caractères). Cela pourrait être une tentative de déni de service.',
        originalContent: content,
        threatType: 'DoS',
      );
    }

    // ── Step 2: Injection Attack Detection ──
    final injectionResult = _checkInjection(content);
    if (injectionResult != null) return injectionResult;

    // ── Step 3: URL Analysis (if content looks like a URL) ──
    if (_looksLikeUrl(content)) {
      return analyzeUrl(content);
    }

    // ── Step 4: Sensitive Data Detection ──
    final sensitiveResult = _checkSensitiveData(content);
    if (sensitiveResult != null) return sensitiveResult;

    // ── Step 5: All clear ✅ ──
    return SecurityResult(
      level: SecurityLevel.safe,
      messageEn: 'Content is safe',
      sanitizedContent: content,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 🔗 URL Analysis Engine
  // ─────────────────────────────────────────────────────────────────────────────

  /// Deep-analyze a URL for threats
  static SecurityResult analyzeUrl(String url) {
    final lowerUrl = url.toLowerCase().trim();

    // ── Blocked schemes (immediate kill) ──
    for (final scheme in _blockedSchemes) {
      if (lowerUrl.startsWith(scheme)) {
        return SecurityResult(
          level: SecurityLevel.blocked,
          messageEn: 'Malicious URL blocked! Dangerous scheme detected: "${scheme.replaceAll(':', '')}"',
          messageAr: 'تم حظر رابط خبيث! تم كشف مخطط خطير: "${scheme.replaceAll(':', '')}"',
          messageFr: 'URL malveillant bloqué ! Schéma dangereux détecté : "${scheme.replaceAll(':', '')}"',
          originalContent: url,
          threatType: 'Malicious Scheme',
        );
      }
    }

    // ── Warning schemes ──
    for (final scheme in _warnSchemes) {
      if (lowerUrl.startsWith(scheme)) {
        return SecurityResult(
          level: SecurityLevel.warning,
          messageEn: 'This URL uses the "$scheme" protocol which may not be safe. Proceed with caution.',
          messageAr: 'هذا الرابط يستخدم بروتوكول "$scheme" الذي قد لا يكون آمناً. تابع بحذر.',
          messageFr: 'Cette URL utilise le protocole "$scheme" qui n\'est peut-être pas sûr. Procédez avec prudence.',
          sanitizedContent: url,
          originalContent: url,
          threatType: 'Suspicious Protocol',
        );
      }
    }

    // ── HTTP without S (insecure) ──
    if (lowerUrl.startsWith('http://')) {
      return SecurityResult(
        level: SecurityLevel.warning,
        messageEn: 'This URL uses an insecure connection (HTTP). Your data could be intercepted. Are you sure you want to open it?',
        messageAr: 'هذا الرابط يستخدم اتصالاً غير مشفر (HTTP). قد يتم اعتراض بياناتك. هل أنت متأكد من فتحه؟',
        messageFr: 'Cette URL utilise une connexion non sécurisée (HTTP). Vos données pourraient être interceptées. Voulez-vous continuer ?',
        sanitizedContent: url,
        originalContent: url,
        threatType: 'Insecure Connection',
      );
    }

    // ── Phishing domain patterns ──
    for (final pattern in _suspiciousDomainPatterns) {
      if (lowerUrl.contains(pattern)) {
        return SecurityResult(
          level: SecurityLevel.warning,
          messageEn: 'Warning: This URL matches known phishing patterns. It might be trying to steal your information.',
          messageAr: 'تحذير: هذا الرابط يطابق أنماط تصيد احتيالي معروفة. قد يحاول سرقة معلوماتك.',
          messageFr: 'Attention : Cette URL correspond à des schémas de phishing connus. Elle pourrait chercher à voler vos informations.',
          sanitizedContent: url,
          originalContent: url,
          threatType: 'Phishing Suspected',
        );
      }
    }

    // ── URL looks safe ──
    return SecurityResult(
      level: SecurityLevel.safe,
      messageEn: 'URL appears safe',
      sanitizedContent: url,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 💉 Injection Detection Engine
  // ─────────────────────────────────────────────────────────────────────────────

  static SecurityResult? _checkInjection(String content) {
    final lowerContent = content.toLowerCase();

    for (final pattern in _injectionPatterns) {
      if (lowerContent.contains(pattern.toLowerCase())) {
        // Attempt sanitization
        String sanitized = content;
        for (final p in _injectionPatterns) {
          sanitized = sanitized.replaceAll(
            RegExp(RegExp.escape(p), caseSensitive: false),
            '',
          );
        }
        sanitized = sanitized.trim();

        // If nothing remains after sanitization, block completely
        if (sanitized.isEmpty) {
          return SecurityResult(
            level: SecurityLevel.blocked,
            messageEn: 'Malicious code injection detected and blocked. The entire input was malicious.',
            messageAr: 'تم كشف وحظر حقن برمجي خبيث. المدخل بالكامل كان خبيثاً.',
            messageFr: 'Injection de code malveillant détectée et bloquée. L\'entrée entière était malveillante.',
            originalContent: content,
            threatType: 'Code Injection',
          );
        }

        // Sanitized version is usable
        return SecurityResult(
          level: SecurityLevel.sanitized,
          messageEn: 'Suspicious code was removed from the input. Clean version will be used.',
          messageAr: 'تم إزالة كود مشبوه من المدخل. سيتم استخدام النسخة النظيفة.',
          messageFr: 'Du code suspect a été supprimé de l\'entrée. La version nettoyée sera utilisée.',
          sanitizedContent: sanitized,
          originalContent: content,
          threatType: 'Code Injection (Sanitized)',
        );
      }
    }

    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 🔐 Sensitive Data Detection
  // ─────────────────────────────────────────────────────────────────────────────

  static SecurityResult? _checkSensitiveData(String content) {
    for (final pattern in _sensitivePatterns) {
      if (pattern.hasMatch(content)) {
        return SecurityResult(
          level: SecurityLevel.warning,
          messageEn: 'This content appears to contain sensitive personal data (e.g., credit card, password). Handle with extreme care.',
          messageAr: 'يبدو أن هذا المحتوى يحتوي على بيانات شخصية حساسة (مثل بطاقة ائتمان أو كلمة مرور). تعامل بحذر شديد.',
          messageFr: 'Ce contenu semble contenir des données personnelles sensibles (ex. carte de crédit, mot de passe). Manipulez avec une extrême prudence.',
          sanitizedContent: content,
          originalContent: content,
          threatType: 'Sensitive Data',
        );
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 🛠️ Utility Methods
  // ─────────────────────────────────────────────────────────────────────────────

  /// Check if a string looks like a URL
  static bool _looksLikeUrl(String content) {
    final lower = content.toLowerCase().trim();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('ftp://') ||
        lower.startsWith('javascript:') ||
        lower.startsWith('data:') ||
        lower.startsWith('file://') ||
        lower.contains('://') ||
        RegExp(r'^www\.\S+\.\S+').hasMatch(lower);
  }

  /// Quick check: does content contain sensitive data?
  static bool containsSensitiveData(String content) {
    for (final pattern in _sensitivePatterns) {
      if (pattern.hasMatch(content)) return true;
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 🖥️ UI — Security Dialog (Decision Matrix Interface)
  // ─────────────────────────────────────────────────────────────────────────────

  /// Show the appropriate security dialog based on analysis result.
  /// Returns `true` if the user/system allows the action, `false` if blocked.
  static Future<bool> handleSecurityResult(
    BuildContext context,
    SecurityResult result, {
    String langCode = 'en',
  }) async {
    switch (result.level) {
      case SecurityLevel.safe:
        return true;

      case SecurityLevel.sanitized:
        // Show a brief notification, auto-allow
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.cleaning_services, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(result.getMessage(langCode))),
                ],
              ),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return true;

      case SecurityLevel.warning:
        return await _showWarningDialog(context, result, langCode);

      case SecurityLevel.blocked:
        if (context.mounted) {
          await _showBlockedDialog(context, result, langCode);
        }
        return false;
    }
  }

  /// Warning dialog — user can choose to proceed or cancel
  static Future<bool> _showWarningDialog(
    BuildContext context,
    SecurityResult result,
    String langCode,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.shield_outlined, color: Colors.orange, size: 48),
        title: Text(
          langCode == 'ar'
              ? '⚠️ تحذير أمني'
              : langCode == 'fr'
                  ? '⚠️ Alerte de Sécurité'
                  : '⚠️ Security Warning',
          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(result.getMessage(langCode), textAlign: TextAlign.center),
            if (result.threatType != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Threat: ${result.threatType}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              langCode == 'ar'
                  ? 'إلغاء'
                  : langCode == 'fr'
                      ? 'Annuler'
                      : 'Cancel',
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(
              langCode == 'ar'
                  ? 'متابعة على مسؤوليتي'
                  : langCode == 'fr'
                      ? 'Continuer quand même'
                      : 'Proceed Anyway',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Blocked dialog — no choice, operation is killed
  static Future<void> _showBlockedDialog(
    BuildContext context,
    SecurityResult result,
    String langCode,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.gpp_bad, color: Colors.red, size: 56),
        title: Text(
          langCode == 'ar'
              ? '🛡️ تم منع نشاط خبيث'
              : langCode == 'fr'
                  ? '🛡️ Activité malveillante bloquée'
                  : '🛡️ Malicious Activity Blocked',
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(result.getMessage(langCode), textAlign: TextAlign.center),
            if (result.threatType != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bug_report, size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 6),
                    Text(
                      result.threatType!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 44),
            ),
            child: Text(
              langCode == 'ar'
                  ? 'فهمت'
                  : langCode == 'fr'
                      ? 'Compris'
                      : 'Understood',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 📜 History Security — Sensitive data handling
  // ─────────────────────────────────────────────────────────────────────────────

  /// Show a warning when sensitive data is found in history
  static Future<bool> showSensitiveDataHistoryWarning(
    BuildContext context, {
    String langCode = 'en',
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.privacy_tip, color: Colors.amber.shade700, size: 48),
        title: Text(
          langCode == 'ar'
              ? '🔐 بيانات حساسة'
              : langCode == 'fr'
                  ? '🔐 Données sensibles'
                  : '🔐 Sensitive Data',
          style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.bold),
        ),
        content: Text(
          langCode == 'ar'
              ? 'هذا السجل يحتوي على معلومات حساسة. نوصي بشدة بحذفه لحماية خصوصيتك.'
              : langCode == 'fr'
                  ? 'Cet enregistrement contient des informations sensibles. Nous recommandons fortement de le supprimer pour protéger votre vie privée.'
                  : 'This entry contains sensitive information. We strongly recommend deleting it to protect your privacy.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              langCode == 'ar'
                  ? 'إبقاء'
                  : langCode == 'fr'
                      ? 'Garder'
                      : 'Keep',
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.delete_forever, color: Colors.white, size: 18),
            label: Text(
              langCode == 'ar'
                  ? 'حذف فوراً'
                  : langCode == 'fr'
                      ? 'Supprimer maintenant'
                      : 'Delete Now',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
