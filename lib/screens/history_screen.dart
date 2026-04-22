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
  final int refreshKey;
  const HistoryScreen({super.key, this.refreshKey = 0});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryItem> _history = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await HistoryManager.getHistory();
    if (mounted) {
      setState(() {
        _history = history;
        _selectedIds.retainWhere((id) => history.any((item) => item.id == id));
        _isLoading = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshKey != oldWidget.refreshKey) {
      _loadHistory();
    }
  }

  Future<void> _clearHistory() async {
    final loc = AppLocalizations.of;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc(context, 'clear_history_title')),
        content: Text(loc(context, 'clear_history_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(
              loc(context, 'confirm'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await HistoryManager.clearHistory();
      _loadHistory();
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    await HistoryManager.deleteSelectedHistory(_selectedIds.toList());
    setState(() {
      _selectedIds.clear();
    });
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
                          if (_selectedIds.isNotEmpty) ...[
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedIds.clear();
                                });
                              },
                              icon: const Icon(Icons.close),
                              label: Text(loc(context, 'clear')),
                            ),
                            TextButton.icon(
                              onPressed: _deleteSelected,
                              icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                              label: Text('${loc(context, 'delete_selected')} (${_selectedIds.length})', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                            )
                          ] else ...[
                            TextButton.icon(
                              onPressed: _clearHistory,
                              icon: Icon(Icons.delete_sweep, color: Theme.of(context).colorScheme.error),
                              label: Text(loc(context, 'clear'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                            )
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          final isSelected = _selectedIds.contains(item.id);
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                                : null,
                            child: ListTile(
                              onTap: () {
                                if (_selectedIds.isNotEmpty) {
                                  _toggleSelection(item.id);
                                } else {
                                  _showHistoryItemDialog(context, item);
                                }
                              },
                              onLongPress: () {
                                _toggleSelection(item.id);
                              },
                              leading: _selectedIds.isNotEmpty
                                  ? Checkbox(
                                      value: isSelected,
                                      onChanged: (val) => _toggleSelection(item.id),
                                    )
                                  : CircleAvatar(
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
        final loc = AppLocalizations.of;
        return AlertDialog(
          title: Text(item.type == 'QR' ? loc(context, 'qr_code') : loc(context, 'barcode_label')),
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
              SizedBox(
                maxHeight: 100,
                child: SingleChildScrollView(
                  child: SelectableText(item.content, textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc(context, 'close')),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final outerContext = this.context;
                ExportHelper.showExportDialog(
                  context: outerContext,
                  boundaryKey: boundaryKey,
                  fileName: 'history_${item.type.toLowerCase()}',
                ).then((_) {
                  if (context.mounted && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                });
              },
              icon: const Icon(Icons.download),
              label: Text(loc(context, 'export')),
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
