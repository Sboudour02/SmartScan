import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:archive/archive.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
            const SnackBar(content: Text('No valid data found in the file.')),
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
      final archive = Archive();
      final total = _parsedData.length;

      for (int i = 0; i < total; i++) {
        final data = _parsedData[i];
        final pngBytes = await _generateQrImage(data);

        // Sanitize filename: replace invalid chars
        final safeName = data
            .replaceAll(RegExp(r'[^\w\s\-.]'), '_')
            .replaceAll(RegExp(r'\s+'), '_');
        final fileName = '${(i + 1).toString().padLeft(3, '0')}_$safeName.png';

        archive.addFile(ArchiveFile(fileName, pngBytes.length, pngBytes));

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

      setState(() => _statusMessage = 'Creating ZIP file...');

      // Encode the ZIP
      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) throw Exception('Failed to create ZIP file');

      final zipBytes = Uint8List.fromList(zipData);

      // Save to temp and share
      final directory = await getTemporaryDirectory();
      final zipFile = File('${directory.path}/smartscan_batch_${DateTime.now().millisecondsSinceEpoch}.zip');
      await zipFile.writeAsBytes(zipBytes);

      setState(() {
        _isProcessing = false;
        _statusMessage = 'Done! $total QR codes generated.';
      });

      if (mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(zipFile.path)],
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      loc(context, 'batch_instructions'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

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
                            Icon(Icons.qr_code_2, size: 16, color: Theme.of(context).colorScheme.primary),
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
                    '${loc(context, 'generate')} ${_parsedData.length} QR',
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
