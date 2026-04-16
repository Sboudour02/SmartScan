import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../utils/export_helper.dart';
import '../utils/history_manager.dart';
import '../utils/localization.dart';

class BarcodeGeneratorScreen extends StatefulWidget {
  const BarcodeGeneratorScreen({super.key});

  @override
  State<BarcodeGeneratorScreen> createState() => _BarcodeGeneratorScreenState();
}

class _BarcodeGeneratorScreenState extends State<BarcodeGeneratorScreen> {
  final GlobalKey _globalKey = GlobalKey();
  
  // Supported Barcode Types
  final List<Map<String, dynamic>> _barcodeTypes = [
    {'name': 'Code 128', 'barcode': Barcode.code128(), 'default': 'CODE128'},
    {'name': 'EAN-13', 'barcode': Barcode.ean13(), 'default': '1234567890128'},
    {'name': 'EAN-8', 'barcode': Barcode.ean8(), 'default': '12345670'},
    {'name': 'UPC-A', 'barcode': Barcode.upcA(), 'default': '123456789012'},
    {'name': 'UPC-E', 'barcode': Barcode.upcE(), 'default': '01234565'},
    {'name': 'Code 39', 'barcode': Barcode.code39(), 'default': 'CODE39'},
    {'name': 'Code 93', 'barcode': Barcode.code93(), 'default': 'CODE93'},
    {'name': 'ITF', 'barcode': Barcode.itf(), 'default': '12345678'},
    {'name': 'DataMatrix', 'barcode': Barcode.dataMatrix(), 'default': 'DataMatrix Data'},
    {'name': 'PDF417', 'barcode': Barcode.pdf417(), 'default': 'PDF417 Data'},
    {'name': 'Aztec', 'barcode': Barcode.aztec(), 'default': 'Aztec Data'},
  ];

  late Map<String, dynamic> _selectedType;
  late TextEditingController _dataController;
  String _barcodeData = '';

  @override
  void initState() {
    super.initState();
    _selectedType = _barcodeTypes[0];
    _dataController = TextEditingController(text: _selectedType['default']);
    _barcodeData = _selectedType['default'];
  }

  @override
  void dispose() {
    _dataController.dispose();
    super.dispose();
  }

  void _onTypeChanged(Map<String, dynamic>? newType) {
    if (newType == null) return;
    setState(() {
      _selectedType = newType;
      // Provide a valid default placeholder to prevent "Invalid data sequence" UI flashes
      _dataController.text = newType['default'];
      _barcodeData = newType['default'];
    });
  }

  Future<void> _handleExport() async {
    if (_barcodeData.trim().isEmpty) return;
    
    // Add to History
    await HistoryManager.addHistory(HistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'Barcode',
      content: _barcodeData,
      format: _selectedType['name'],
      timestamp: DateTime.now(),
    ));

    if (mounted) {
      ExportHelper.showExportDialog(
        context: context,
        boundaryKey: _globalKey,
        fileName: 'barcode',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Live Preview Card
            Hero(
              tag: 'barcode_preview',
              child: Card(
                elevation: 12,
                shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.surface,
                        Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(32.0),
                  child: RepaintBoundary(
                    key: _globalKey,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: BarcodeWidget(
                        barcode: _selectedType['barcode'],
                        data: _barcodeData.isEmpty ? ' ' : _barcodeData,
                        width: double.infinity,
                        height: 120,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        errorBuilder: (context, error) => const Center(
                          child: Text(
                            'Invalid sequence',
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Format Selector
            Text(
              loc(context, 'choose_format'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _barcodeTypes.length,
                itemBuilder: (context, index) {
                  final type = _barcodeTypes[index];
                  final isSelected = _selectedType['name'] == type['name'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(type['name']),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) _onTypeChanged(type);
                      },
                      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: isSelected ? Theme.of(context).colorScheme.primary : null,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Content Input
            TextFormField(
              controller: _dataController,
              style: const TextStyle(fontSize: 18, letterSpacing: 1.2),
              decoration: InputDecoration(
                labelText: loc(context, 'content_type'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                prefixIcon: const Icon(Icons.qr_code),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _dataController.clear();
                    setState(() => _barcodeData = '');
                  },
                ),
              ),
              onChanged: (val) => setState(() => _barcodeData = val),
            ),
            
            const SizedBox(height: 32),
            
            // Export Button
            Center(
              child: ElevatedButton.icon(
                onPressed: _barcodeData.isEmpty ? null : _handleExport,
                icon: const Icon(Icons.ios_share, size: 20),
                label: Text(
                  loc(context, 'export'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
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

