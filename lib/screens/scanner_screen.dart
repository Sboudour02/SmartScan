import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/history_manager.dart';
import '../utils/localization.dart';
import '../utils/content_parser.dart';
import '../providers/locale_provider.dart';
import '../widgets/custom_barcode_overlay.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/security_helper.dart';

class ScannerScreen extends StatefulWidget {
  final bool isActive;
  const ScannerScreen({super.key, this.isActive = true});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  String? _barcodeValue;
  bool _isProcessing = false;

  final Map<String, int> _barcodeDetectionCounts = {};
  DateTime? _lastDetectionTime;

  late AnimationController _animationController;

  bool _isUrl(String value) {
    return Uri.tryParse(value)?.hasScheme ?? false;
  }

  bool get _isWifi => _barcodeValue != null && !_isUrl(_barcodeValue!) && _barcodeValue!.toUpperCase().startsWith('WIFI:');
  bool get _isVCard => _barcodeValue != null && (_barcodeValue!.toUpperCase().startsWith('BEGIN:VCARD') || _barcodeValue!.toUpperCase().startsWith('MECARD:'));

  String? _getWifiPassword() {
    if (_barcodeValue == null) return null;
    final match = RegExp(r'P:(.*?)(;|$)').firstMatch(_barcodeValue!);
    return match?.group(1);
  }

  void _copyWifiPassword() {
    final pass = _getWifiPassword();
    if (pass != null && pass.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: pass));
      final loc = (String key) => AppLocalizations.of(context, key);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc('copy_password'))),
      );
    }
  }

  Future<void> _shareVCard() async {
    if (_barcodeValue == null) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/contact.vcf');
      await tempFile.writeAsString(_barcodeValue!);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(tempFile.path, mimeType: 'text/vcard')
          ],
          text: 'Contact',
        ),
      );
    } catch (e) {
      _shareResult();
    }
  }

  String _getPreview(String url) {
    try {
      if (_isWifi) {
        final match = RegExp(r'S:(.*?)(;|$)').firstMatch(url);
        return match != null ? 'WiFi: ${match.group(1)}' : 'WiFi Network';
      }
      if (_isVCard) {
        final nameMatch = RegExp(r'(?:FN:|N:)(.*?)(?:\r?\n|;|$)').firstMatch(url);
        return nameMatch != null ? 'Contact: ${nameMatch.group(1)?.replaceAll(';', ' ')}' : 'Contact Card';
      }

      String tempUrl = url.trim();
      final lowerUrl = tempUrl.toLowerCase();
      if (lowerUrl.startsWith('mailto:')) return tempUrl.substring(7);
      if (lowerUrl.startsWith('tel:')) return tempUrl.substring(4);
      if (lowerUrl.startsWith('sms:')) return tempUrl.substring(4);
      if (lowerUrl.startsWith('geo:')) return 'Location';

      if (!ContentParser.hasScheme(tempUrl)) {
        tempUrl = 'https://$tempUrl';
      }
      final uri = Uri.parse(tempUrl);
      final host = uri.host.replaceFirst('www.', '');
      return host.isNotEmpty ? host : url;
    } catch (e) {
      return url;
    }
  }

  Future<void> _openUrl() async {
    if (_barcodeValue == null) return;
    String url = _barcodeValue!.trim();

    if (!ContentParser.hasScheme(url)) {
      url = 'https://$url';
    }

    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) {
          final loc = (String key) => AppLocalizations.of(context, key);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc('cannot_open_link')),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        final loc = (String key) => AppLocalizations.of(context, key);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc('cannot_open_link')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant ScannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _scannerController.start();
      } else {
        _scannerController.stop();
        _barcodeDetectionCounts.clear();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  bool _isValidBarcodeFormat(Barcode barcode) {
    if (barcode.rawValue == null || barcode.rawValue!.isEmpty) return false;
    final value = barcode.rawValue!;

    switch (barcode.format) {
      case BarcodeFormat.ean13:
        return value.length == 13 && RegExp(r'^\d{13}$').hasMatch(value);
      case BarcodeFormat.ean8:
        return value.length == 8 && RegExp(r'^\d{8}$').hasMatch(value);
      case BarcodeFormat.upcA:
        return value.length == 12 && RegExp(r'^\d{12}$').hasMatch(value);
      case BarcodeFormat.upcE:
        return value.length == 6 && RegExp(r'^\d{6}$').hasMatch(value);
      case BarcodeFormat.code39:
      case BarcodeFormat.code93:
      case BarcodeFormat.code128:
      case BarcodeFormat.itf14:
        return value.length >= 3;
      default:
        return true;
    }
  }

  Future<void> _handleBarcode(Barcode barcode) async {
    if (_isProcessing) return;
    if (!_isValidBarcodeFormat(barcode)) return;

    final now = DateTime.now();
    final rawValue = barcode.rawValue!;

    if (_lastDetectionTime != null && now.difference(_lastDetectionTime!).inMilliseconds > 500) {
      _barcodeDetectionCounts.clear();
    }

    _lastDetectionTime = now;
    _barcodeDetectionCounts.update(rawValue, (count) => count + 1, ifAbsent: () => 1);

    if (_barcodeDetectionCounts[rawValue]! < 2) return;

    if (rawValue != _barcodeValue) {
      _barcodeDetectionCounts.clear();
      setState(() {
        _isProcessing = true;
      });

      final securityResult = SecurityHelper.analyzeContent(rawValue);
      final langCode = mounted
          ? Provider.of<LocaleProvider>(context, listen: false).locale.languageCode
          : 'en';

      if (securityResult.level == SecurityLevel.blocked) {
        if (mounted) {
          await SecurityHelper.handleSecurityResult(context, securityResult, langCode: langCode);
          setState(() => _isProcessing = false);
        }
        return;
      }

      if (securityResult.level == SecurityLevel.warning) {
        if (mounted) {
          final proceed = await SecurityHelper.handleSecurityResult(context, securityResult, langCode: langCode);
          if (!proceed) {
            setState(() => _isProcessing = false);
            return;
          }
        }
      }

      if (securityResult.level == SecurityLevel.sanitized && mounted) {
        await SecurityHelper.handleSecurityResult(context, securityResult, langCode: langCode);
      }

      final safeValue = securityResult.sanitizedContent ?? rawValue;

      setState(() {
        _barcodeValue = safeValue;
      });

      await HistoryManager.addHistory(HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'Scan',
        content: safeValue,
        timestamp: DateTime.now(),
      ));

      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.click);

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);

    if (xFile != null) {
      final BarcodeCapture? capture = await _scannerController.analyzeImage(xFile.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        await _handleBarcode(capture.barcodes.first);
      } else {
        if (mounted) {
          final loc = (String key) => AppLocalizations.of(context, key);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc('no_qr_found'))),
          );
        }
      }
    }
  }

  void _copyToClipboard() {
    if (_barcodeValue != null) {
      Clipboard.setData(ClipboardData(text: _barcodeValue!));
      final loc = (String key) => AppLocalizations.of(context, key);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc('copied'))),
      );
    }
  }

  void _shareResult() {
    if (_barcodeValue != null) {
      SharePlus.instance.share(ShareParams(text: _barcodeValue!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = (String key) => AppLocalizations.of(context, key);

    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            if (capture.barcodes.isNotEmpty) {
              _handleBarcode(capture.barcodes.first);
            }
          },
        ),

        if (_isProcessing || _barcodeValue != null)
          RepaintBoundary(
            child: CustomBarcodeOverlay(controller: _scannerController),
          ),

        StreamBuilder<BarcodeCapture>(
          stream: _scannerController.barcodes,
          builder: (context, snapshot) {
            final shouldHideStaticOverlay = _isProcessing || _barcodeValue != null;
            if (shouldHideStaticOverlay) return const SizedBox.shrink();

            return Stack(
              children: [
                ColorFiltered(
                  colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.6), BlendMode.srcOut),
                  child: Stack(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          backgroundBlendMode: BlendMode.dstOut,
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: SizedBox(
                    width: 250,
                    height: 250,
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Stack(
                          children: [
                            Positioned(
                              top: _animationController.value * 240,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context).colorScheme.primary,
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        Positioned(
          top: 40,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.flash_on, color: Colors.white, size: 32),
                onPressed: () => _scannerController.toggleTorch(),
              ),
              IconButton(
                icon: const Icon(Icons.image, color: Colors.white, size: 32),
                onPressed: _pickImageFromGallery,
              ),
              IconButton(
                icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 32),
                tooltip: loc('switch_camera'),
                onPressed: () => _scannerController.switchCamera(),
              ),
            ],
          ),
        ),

        if (_barcodeValue != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5)
                ],
              ),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          (_barcodeValue != null && _isUrl(_barcodeValue!)) ? Icons.language : Icons.qr_code_scanner,
                          color: Theme.of(context).colorScheme.primary
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'SmartScan',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Material(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              setState(() {
                                _barcodeValue = null;
                                _isProcessing = false;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 80,
                      child: SingleChildScrollView(
                        child: Text(
                          (_barcodeValue != null && _isUrl(_barcodeValue!)) ? _getPreview(_barcodeValue!) : (_barcodeValue ?? ''),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: (_barcodeValue != null && _isUrl(_barcodeValue!)) ? 22 : 18,
                            fontWeight: (_barcodeValue != null && _isUrl(_barcodeValue!)) ? FontWeight.bold : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    if (_barcodeValue != null && _isUrl(_barcodeValue!))
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: SizedBox(
                          height: 60,
                          child: SingleChildScrollView(
                            child: Text(
                              _barcodeValue!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (_barcodeValue != null && _isUrl(_barcodeValue!))
                          ElevatedButton.icon(
                            onPressed: _openUrl,
                            icon: const Icon(Icons.open_in_browser),
                            label: Text(loc('open')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        if (_isWifi)
                          ElevatedButton.icon(
                            onPressed: _copyWifiPassword,
                            icon: const Icon(Icons.copy),
                            label: Text(loc('copy_password')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        if (_isVCard)
                          ElevatedButton.icon(
                            onPressed: _shareVCard,
                            icon: const Icon(Icons.share),
                            label: Text(loc('add_contact')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ElevatedButton.icon(
                          onPressed: _copyToClipboard,
                          icon: const Icon(Icons.copy),
                          label: Text(loc('copy')),
                        ),
                        ElevatedButton.icon(
                          onPressed: _shareResult,
                          icon: const Icon(Icons.share),
                          label: Text(loc('share')),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
