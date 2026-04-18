import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/history_manager.dart';
import '../utils/localization.dart';
import '../utils/export_helper.dart';
import '../utils/security_helper.dart';
import '../providers/locale_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryItem> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await HistoryManager.getHistory();
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    await HistoryManager.clearHistory();
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of;

    return Center(
      child: _isLoading
          ? const CircularProgressIndicator()
          : _history.isEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(loc(context, 'history_empty'), style: TextStyle(color: Colors.grey.shade500, fontSize: 18)),
                  ],
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: _clearHistory,
                            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                            label: Text('Clear', style: const TextStyle(color: Colors.redAccent)),
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              onTap: () => _showHistoryItemDialog(context, item),
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                child: Icon(
                                  item.type == 'QR' ? Icons.qr_code_2 : Icons.view_column,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              title: Text(item.content, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${item.type} ${item.format != null ? "(${item.format})" : ""}'),
                              trailing: Text(
                                "${item.timestamp.day}/${item.timestamp.month}/${item.timestamp.year}",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  void _showHistoryItemDialog(BuildContext context, HistoryItem item) async {
    // ═══ 🛡️ AntiGravity Security Check ═══
    if (SecurityHelper.containsSensitiveData(item.content)) {
      final langCode = mounted
          ? Provider.of<LocaleProvider>(context, listen: false).locale.languageCode
          : 'en';
      final shouldDelete = await SecurityHelper.showSensitiveDataHistoryWarning(context, langCode: langCode);
      if (shouldDelete) {
        await HistoryManager.deleteHistory(item.id);
        _loadHistory();
        return;
      }
    }
    // ═══ End Security Check ═══

    if (!context.mounted) return;

    final GlobalKey boundaryKey = GlobalKey();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.type == 'QR' ? 'QR Code' : 'Barcode'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: boundaryKey,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: item.type == 'QR'
                      ? QrImageView(
                          data: item.content,
                          size: 200,
                        )
                      : BarcodeWidget(
                          data: item.content,
                          barcode: _getBarcodeFormat(item.format),
                          width: 200,
                          height: 100,
                          style: const TextStyle(fontSize: 14),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(item.content, textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ExportHelper.showExportDialog(
                  context: context,
                  boundaryKey: boundaryKey,
                  fileName: 'history_${item.type.toLowerCase()}',
                );
              },
              icon: const Icon(Icons.download),
              label: const Text('Export'),
            ),
          ],
        );
      },
    );
  }

  Barcode _getBarcodeFormat(String? formatStr) {
    if (formatStr == null) return Barcode.code128();
    switch (formatStr) {
      case 'BarcodeType.CodeEAN13':
      case 'EAN_13':
      case 'EAN 13': return Barcode.ean13();
      case 'BarcodeType.CodeEAN8':
      case 'EAN_8':
      case 'EAN 8': return Barcode.ean8();
      case 'BarcodeType.CodeUPCA':
      case 'UPC_A':
      case 'UPC A': return Barcode.upcA();
      case 'BarcodeType.CodeUPCE':
      case 'UPC_E':
      case 'UPC E': return Barcode.upcE();
      case 'BarcodeType.Code39':
      case 'CODE_39':
      case 'Code 39': return Barcode.code39();
      case 'BarcodeType.Code93':
      case 'CODE_93':
      case 'Code 93': return Barcode.code93();
      case 'BarcodeType.CodeCodabar':
      case 'CODABAR':
      case 'Codabar': return Barcode.codabar();
      case 'BarcodeType.CodeITF':
      case 'ITF': return Barcode.itf();
      case 'BarcodeType.DataMatrix':
      case 'DATA_MATRIX':
      case 'Data Matrix': return Barcode.dataMatrix();
      case 'BarcodeType.Aztec':
      case 'AZTEC':
      case 'Aztec': return Barcode.aztec();
      case 'BarcodeType.PDF417':
      case 'PDF_417':
      case 'PDF417': return Barcode.pdf417();
      case 'BarcodeType.Code128':
      case 'CODE_128':
      case 'Code 128': 
      default: return Barcode.code128();
    }
  }
}
