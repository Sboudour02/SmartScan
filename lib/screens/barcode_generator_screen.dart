import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:provider/provider.dart';
import '../utils/export_helper.dart';
import '../utils/history_manager.dart';
import '../utils/localization.dart';
import '../utils/security_helper.dart';
import '../providers/locale_provider.dart';

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

  bool _isNumericFormat(String typeName) {
    return ['EAN-13', 'EAN-8', 'UPC-A', 'UPC-E', 'ITF'].contains(typeName);
  }

  String _getErrorMessage(String error) {
    final lowerError = error.toLowerCase();
    final typeName = _selectedType['name'];
    
    if (lowerError.contains('length') || lowerError.contains('digit') || lowerError.contains('short') || lowerError.contains('long')) {
      if (typeName == 'EAN-13') return 'Invalid length. EAN-13 requires 12 or 13 digits.';
      if (typeName == 'EAN-8') return 'Invalid length. EAN-8 requires 7 or 8 digits.';
      if (typeName == 'UPC-A') return 'Invalid length. UPC-A requires 11 or 12 digits.';
      if (typeName == 'UPC-E') return 'Invalid length. UPC-E requires 6, 7, or 8 digits.';
      if (typeName == 'ITF') return 'Invalid length. ITF requires an even number of digits.';
      return 'Invalid length for $typeName.';
    } else if (lowerError.contains('checksum')) {
      return 'Invalid checksum digit. Please verify your sequence.';
    } else if (lowerError.contains('character') || lowerError.contains('sequence') || lowerError.contains('valid')) {
      if (_isNumericFormat(typeName)) {
        return 'Error: This format accepts numbers only.';
      }
      return 'Invalid sequence or characters for $typeName.';
    }
    return error;
  }

  @override
  void initState() {
    super.initState();
    _selectedType = _barcodeTypes[0];
    _dataController = TextEditingController();
    _barcodeData = '';
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
      // Keep current user input when switching types; clear only if empty
      // Don't overwrite with format default — let the user type their own data
    });
  }

  Future<void> _handleExport() async {
    if (_barcodeData.trim().isEmpty) return;

    // ═══ 🛡️ AntiGravity Security Check ═══
    final securityResult = SecurityHelper.analyzeContent(_barcodeData);
    final langCode = mounted
        ? Provider.of<LocaleProvider>(context, listen: false).locale.languageCode
        : 'en';

    if (securityResult.level == SecurityLevel.blocked) {
      if (mounted) {
        await SecurityHelper.handleSecurityResult(context, securityResult, langCode: langCode);
      }
      return;
    }

    if (securityResult.level == SecurityLevel.warning) {
      if (mounted) {
        final proceed = await SecurityHelper.handleSecurityResult(context, securityResult, langCode: langCode);
        if (!proceed) return;
      }
    }

    if (securityResult.level == SecurityLevel.sanitized && mounted) {
      await SecurityHelper.handleSecurityResult(context, securityResult, langCode: langCode);
      setState(() => _barcodeData = securityResult.sanitizedContent ?? _barcodeData);
    }
    // ═══ End Security Check ═══
    
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
    final loc = (String key) => AppLocalizations.of(context, key);

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
                        data: _barcodeData.isEmpty ? _selectedType['default'] : _barcodeData,
                        width: double.infinity,
                        height: 120,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        errorBuilder: (context, error) => Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              _getErrorMessage(error),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                            ),
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
              loc('choose_format'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white,
                      Colors.white,
                      Colors.white,
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.7, 0.85, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            ),
            
            const SizedBox(height: 24),
            
            // Content Input
            TextFormField(
              controller: _dataController,
              style: const TextStyle(fontSize: 18, letterSpacing: 1.2),
              keyboardType: _isNumericFormat(_selectedType['name']) 
                  ? TextInputType.number 
                  : TextInputType.text,
              inputFormatters: _isNumericFormat(_selectedType['name']) 
                  ? [FilteringTextInputFormatter.digitsOnly] 
                  : null,
              decoration: InputDecoration(
                labelText: loc('content_type'),
                hintText: _isNumericFormat(_selectedType['name']) 
                    ? 'Enter numbers only...' 
                    : 'Enter text or numbers...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                prefixIcon: const Icon(Icons.view_week_outlined),
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
                  loc('export'),
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

