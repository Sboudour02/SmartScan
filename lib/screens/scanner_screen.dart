import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/history_manager.dart';
import '../utils/localization.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  String? _barcodeValue;
  String? _barcodeType;
  bool _isProcessing = false;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(Barcode barcode) async {
    if (_isProcessing) return;
    if (barcode.rawValue != null && barcode.rawValue != _barcodeValue) {
      setState(() {
        _isProcessing = true;
        _barcodeValue = barcode.rawValue;
        _barcodeType = barcode.format.name;
      });

      // Save to History
      await HistoryManager.addHistory(HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'Scan',
        content: _barcodeValue!,
        timestamp: DateTime.now(),
      ));

      HapticFeedback.heavyImpact();
      
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
        _handleBarcode(capture.barcodes.first);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No QR/Barcode found in image.')),
          );
        }
      }
    }
  }

  void _copyToClipboard() {
    if (_barcodeValue != null) {
      Clipboard.setData(ClipboardData(text: _barcodeValue!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard')),
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
    final loc = AppLocalizations.of;

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
        
        // Custom Scanner Overlay
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

        // Scanning Animation Line
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

        // Top Controls
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
                icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 32),
                onPressed: () => _scannerController.switchCamera(),
              ),
            ],
          ),
        ),

        // Result Bottom Sheet View
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.qr_code_scanner, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        _barcodeType ?? 'Result',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _barcodeValue!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _copyToClipboard,
                        icon: const Icon(Icons.copy),
                        label: Text(loc(context, 'copy')),
                      ),
                      ElevatedButton.icon(
                        onPressed: _shareResult,
                        icon: const Icon(Icons.share),
                        label: Text(loc(context, 'share')),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
      ],
    );
  }
}
