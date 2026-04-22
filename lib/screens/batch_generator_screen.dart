import 'dart:io';

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:async_zip/async_zip.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import '../utils/localization.dart';

class BatchGeneratorScreen extends StatefulWidget {
  const BatchGeneratorScreen({super.key});

  @override
  State<BatchGeneratorScreen> createState() => _BatchGeneratorScreenState();
}

class _BatchGeneratorScreenState extends State<BatchGeneratorScreen> {
  bool _isProcessing = false;
  List<String> _parsedData = [];
  String? _fileName;
  double _progress = 0.0;
  String _statusMessage = '';
  int _generatedCount = 0;

  String _selectedFormat = 'QR Code';
  final List<String> _formats = [
    'QR Code',
    'Code 128',
    'EAN-13',
    'EAN-8',
    'UPC-A',
    'UPC-E',
    'ITF'
  ];

  Barcode _getBarcodeFromFormat(String format) {
    switch (format) {
      case 'Code 128': return Barcode.code128();
      case 'EAN-13': return Barcode.ean13();
      case 'EAN-8': return Barcode.ean8();
      case 'UPC-A': return Barcode.upcA();
      case 'UPC-E': return Barcode.upcE();
      case 'ITF': return Barcode.itf();
      default: return Barcode.code128();
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    setState(() {
      _fileName = file.name;
      _parsedData = [];
    });

    try {
      final ext = file.extension?.toLowerCase();
      List<String> data = [];

      if (ext == 'csv') {
        data = await _parseCSV(file.path!);
      } else if (ext == 'xlsx' || ext == 'xls') {
        data = await _parseExcel(file.path!);
      }

      // Remove empty entries
      data = data.where((s) => s.trim().isNotEmpty).toList();

      if (data.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context, 'no_valid_data'))),
          );
        }
        return;
      }

      setState(() {
        _parsedData = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading file: $e')),
        );
      }
    }
  }

  Future<List<String>> _parseCSV(String filePath) async {
    final file = File(filePath);
    final csvString = await file.readAsString();
    final rows = Csv().decode(csvString);

    final List<String> result = [];
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].isNotEmpty) {
        final val = rows[i][0].toString().trim();
        if (val.isNotEmpty) {
          result.add(val);
        }
      }
    }
    return result;
  }

  Future<List<String>> _parseExcel(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final List<String> result = [];
    // Read the first sheet
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName];

    if (sheet == null) return result;

    for (int i = 0; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.isNotEmpty && row[0] != null) {
        final val = row[0]!.value?.toString().trim() ?? '';
        if (val.isNotEmpty) {
          result.add(val);
        }
      }
    }
    return result;
  }

  Future<void> _generateAndExport() async {
    if (_parsedData.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _generatedCount = 0;
      _statusMessage = 'Generating QR codes...';
    });

    try {
      final directory = await getTemporaryDirectory();
      final zipPath = '${directory.path}/smartscan_batch_${DateTime.now().millisecondsSinceEpoch}.zip';
      final zipFile = File(zipPath);

      final writer = ZipFileWriter(zipFile);
      final total = _parsedData.length;

      for (int i = 0; i < total; i++) {
        final data = _parsedData[i];
        final Uint8List pngBytes;
        if (_selectedFormat == 'QR Code') {
          pngBytes = await _generateQrImage(data);
        } else {
          try {
             pngBytes = await _generateBarcodeImage(data, _getBarcodeFromFormat(_selectedFormat));
          } catch(e) {
             throw Exception('Failed on element "$data": $e');
          }
        }

        // Sanitize filename: replace invalid chars
        final safeName = data
            .replaceAll(RegExp(r'[^\w\s\-.]'), '_')
            .replaceAll(RegExp(r'\s+'), '_');
        final fileName = '${(i + 1).toString().padLeft(3, '0')}_$safeName.png';

        // Write image to ZIP directly from bytes to avoid excessive temporary files
        await writer.addFile(fileName, pngBytes);

        setState(() {
          _progress = (i + 1) / total;
          _generatedCount = i + 1;
          _statusMessage = 'Generated $_generatedCount / $total';
        });

        // Small delay to let the UI breathe
        if (i % 5 == 0) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      await writer.close();

      setState(() {
        _isProcessing = false;
        _statusMessage = 'Done! $total QR codes generated.';
      });

      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(zipPath)],
            text: 'Batch QR Codes ($total items) — SmartScan',
            sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Error: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<Uint8List> _generateBarcodeImage(String data, Barcode barcodeType) async {
    final imageSize = 512.0;
    final barcodeWidth = 480.0;
    final barcodeHeight = 240.0;
    
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Fill white background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, imageSize, imageSize),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    final recipe = barcodeType.make(
      data,
      width: barcodeWidth,
      height: barcodeHeight,
      drawText: true,
      fontHeight: 48,
      textPadding: 16,
    );

    final barStyle = Paint()..color = const Color(0xFF000000);
    final dx = (imageSize - barcodeWidth) / 2;
    final dy = (imageSize - barcodeHeight) / 2;

    for (var element in recipe) {
      if (element is BarcodeBar) {
        if (element.black) {
          canvas.drawRect(
            Rect.fromLTWH(
              dx + element.left,
              dy + element.top,
              element.width,
              element.height,
            ),
            barStyle,
          );
        }
      } else if (element is BarcodeText) {
        final align = element.align == BarcodeTextAlign.left ? TextAlign.left : 
                      element.align == BarcodeTextAlign.right ? TextAlign.right : TextAlign.center;
        
        final builder = ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textAlign: align,
            fontSize: element.height,
          ),
        )
          ..pushStyle(ui.TextStyle(color: const Color(0xFF000000)))
          ..addText(element.text);
        final paragraph = builder.build();
        paragraph.layout(ui.ParagraphConstraints(width: element.width));
        
        canvas.drawParagraph(
          paragraph,
          Offset(dx + element.left, dy + element.top + paragraph.alphabeticBaseline - paragraph.height),
        );
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(imageSize.toInt(), imageSize.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// Generate a QR code as a PNG Uint8List using QrPainter
  Future<Uint8List> _generateQrImage(String data) async {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Color(0xFF000000),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF000000),
      ),
    );

    final imageSize = 512.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Fill white background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, imageSize, imageSize),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    qrPainter.paint(canvas, Size(imageSize, imageSize));

    final picture = recorder.endRecording();
    final img = await picture.toImage(imageSize.toInt(), imageSize.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of;

    return Scaffold(
      appBar: AppBar(title: Text(loc(context, 'batch_generation'))),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: 24.0,
          left: 24.0,
          right: 24.0,
          bottom: MediaQuery.of(context).padding.bottom + 24.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions Banner
            if (_parsedData.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.upload_file_rounded,
                        size: 100,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        loc(context, 'batch_empty_title'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        loc(context, 'batch_empty_msg'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.file_upload),
                        label: Text(loc(context, 'batch_upload_cta')),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 28,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc(context, 'batch_instructions'),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              loc(context, 'batch_column_note'),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Select Format
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${loc(context, 'choose_format')}:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedFormat,
                        items: _formats.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedFormat = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Warning for numeric formats
            if (['EAN-13', 'EAN-8', 'UPC-A', 'UPC-E', 'ITF'].contains(_selectedFormat))
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${loc(context, 'numeric_warning')} $_selectedFormat.',
                        style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),

            // Select File Button
            OutlinedButton.icon(
              onPressed: _isProcessing ? null : _pickFile,
              icon: const Icon(Icons.upload_file, size: 22),
              label: Text(
                _fileName ?? loc(context, 'select_file'),
                style: const TextStyle(fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                side: BorderSide(
                  color: _fileName != null
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),

            // Parsed Data Info
            if (_parsedData.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${_parsedData.length} ${loc(context, 'items_found')}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      // Preview first 5 items
                      Text(
                        loc(context, 'preview'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._parsedData.take(5).map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          children: [
                            Icon(
                               Uri.tryParse(item)?.hasScheme == true ? Icons.qr_code_2 : RegExp(r'^\d+$').hasMatch(item) ? Icons.view_week : Icons.qr_code_2, 
                               size: 16, 
                               color: Theme.of(context).colorScheme.primary
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      )),
                      if (_parsedData.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            '... +${_parsedData.length - 5} ${loc(context, 'more_items')}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],

            // Progress Section
            if (_isProcessing) ...[
              const SizedBox(height: 24),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        _statusMessage,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 10,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Done message
            if (!_isProcessing && _statusMessage.startsWith('Done')) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                color: Colors.green.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Generate Button
            if (_parsedData.isNotEmpty && !_isProcessing)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.tertiary,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _generateAndExport,
                  icon: const Icon(Icons.auto_awesome, size: 22),
                  label: Text(
                    '${loc(context, 'generate')} ${_parsedData.length} ${_selectedFormat == 'QR Code' ? 'QR' : _selectedFormat}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
