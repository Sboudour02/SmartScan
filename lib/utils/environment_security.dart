import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 🛡️ AntiGravity Security Protocol — Environment Monitoring Engine
// Protected App: SmartScan v1.0
// ═══════════════════════════════════════════════════════════════════════════════

class EnvironmentSecurity {
  static const MethodChannel _channel = MethodChannel('com.smartscan/security');

  /// Paranoid Mode: activated when device is compromised (rooted)
  static bool _isParanoidMode = false;
  static bool get isParanoidMode => _isParanoidMode;

  /// Cached environment check results
  static Map<String, bool>? _cachedResults;

  // ─────────────────────────────────────────────────────────────────────────────
  // 🔍 Full Environment Check
  // ─────────────────────────────────────────────────────────────────────────────

  /// Run all environment security checks.
  /// Should be called once at app startup.
  static Future<Map<String, bool>> checkEnvironment() async {
    if (_cachedResults != null) return _cachedResults!;

    final results = <String, bool>{};

    results['rooted'] = await isRooted();
    results['emulator'] = await isEmulator();

    // Enable paranoid mode if device is rooted
    if (results['rooted'] == true) {
      _isParanoidMode = true;
    }

    _cachedResults = results;
    return results;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 📱 Root Detection
  // ─────────────────────────────────────────────────────────────────────────────

  /// Check if the Android device is rooted
  static Future<bool> isRooted() async {
    if (!Platform.isAndroid) return false;

    try {
      // Method 1: Check common root binary paths
      final rootPaths = [
        '/system/app/Superuser.apk',
        '/system/xbin/su',
        '/system/bin/su',
        '/sbin/su',
        '/data/local/xbin/su',
        '/data/local/bin/su',
        '/data/local/su',
        '/su/bin/su',
        '/system/bin/failsafe/su',
        '/system/sd/xbin/su',
        '/system/usr/we-need-root/su',
        '/data/adb/magisk',
      ];

      for (final path in rootPaths) {
        try {
          if (await File(path).exists()) return true;
        } catch (_) {}
      }

      // Method 2: Try native method channel check
      try {
        final result = await _channel.invokeMethod<bool>('isRooted');
        if (result == true) return true;
      } catch (_) {
        // Channel not available, rely on file checks above
      }

      // Method 3: Check for dangerous properties
      try {
        final result = await Process.run('getprop', ['ro.debuggable']);
        if (result.stdout.toString().trim() == '1') {
          // Debuggable build — suspicious but not definitive
        }
      } catch (_) {}
    } catch (_) {}

    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 🖥️ Emulator Detection
  // ─────────────────────────────────────────────────────────────────────────────

  /// Check if the app is running on an emulator
  static Future<bool> isEmulator() async {
    if (!Platform.isAndroid) return false;

    try {
      // Try native method channel first
      final result = await _channel.invokeMethod<bool>('isEmulator');
      if (result != null) return result;
    } catch (_) {
      // Fallback to basic checks
      try {
        // Check hardware properties that indicate emulator
        final checks = [
          ['ro.hardware', ['goldfish', 'ranchu', 'vbox86']],
          ['ro.product.model', ['sdk', 'Emulator', 'Android SDK']],
          ['ro.kernel.qemu', ['1']],
          ['ro.product.brand', ['generic', 'generic_x86']],
        ];

        for (final check in checks) {
          try {
            final result = await Process.run('getprop', [check[0] as String]);
            final value = result.stdout.toString().trim().toLowerCase();
            for (final indicator in check[1] as List<String>) {
              if (value.contains(indicator.toLowerCase())) return true;
            }
          } catch (_) {}
        }
      } catch (_) {}
    }

    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 🖥️ UI — Environment Warning Dialog
  // ─────────────────────────────────────────────────────────────────────────────

  /// Show startup security warnings if environment is compromised
  static Future<void> showEnvironmentWarnings(
    BuildContext context,
    Map<String, bool> results, {
    String langCode = 'en',
  }) async {
    final warnings = <String>[];

    if (results['rooted'] == true) {
      warnings.add(langCode == 'ar'
          ? '🔓 جهازك مكسور الحماية (Root). تم تفعيل الوضع المشدد.'
          : langCode == 'fr'
              ? '🔓 Votre appareil est rooté. Le mode renforcé a été activé.'
              : '🔓 Your device is rooted. Paranoid Mode has been activated.');
    }

    if (results['emulator'] == true) {
      warnings.add(langCode == 'ar'
          ? '🖥️ التطبيق يعمل على محاكي. بعض الميزات قد تكون مقيدة.'
          : langCode == 'fr'
              ? '🖥️ L\'application fonctionne sur un émulateur. Certaines fonctionnalités peuvent être restreintes.'
              : '🖥️ App is running on an emulator. Some features may be restricted.');
    }

    if (warnings.isEmpty) return;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(
          _isParanoidMode ? Icons.security : Icons.info_outline,
          color: _isParanoidMode ? Colors.red : Colors.orange,
          size: 48,
        ),
        title: Text(
          langCode == 'ar'
              ? '🛡️ تنبيه أمني'
              : langCode == 'fr'
                  ? '🛡️ Alerte de Sécurité'
                  : '🛡️ Security Notice',
          style: TextStyle(
            color: _isParanoidMode ? Colors.red : Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: warnings
              .map((w) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(w, style: const TextStyle(fontSize: 14)),
                  ))
              .toList(),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
            ),
            child: Text(
              langCode == 'ar'
                  ? 'فهمت'
                  : langCode == 'fr'
                      ? 'Compris'
                      : 'Understood',
            ),
          ),
        ],
      ),
    );
  }
}
