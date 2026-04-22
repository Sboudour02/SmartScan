import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../utils/export_helper.dart';
import '../utils/history_manager.dart';
import '../utils/localization.dart';
import '../utils/security_helper.dart';
import '../providers/locale_provider.dart';

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  final GlobalKey _globalKey = GlobalKey();
  
  String _qrData = 'SmartScan App';
  Color _qrColor = Colors.black;
  bool _isRoundEye = false;
  String? _logoPath;
  String _selectedTemplate = 'URL';
  String _selectedSize = 'Medium';
  String _selectedFormat = 'PNG';

  final Map<String, double> _sizeMap = {
    'Small': 150.0,
    'Medium': 200.0,
    'Large': 300.0,
  };

  final List<String> _formats = ['PNG', 'JPEG', 'PDF', 'SVG'];
  
  final TextEditingController _dataController = TextEditingController(text: 'https://smartscan.example.com');
  final TextEditingController _wifiSsidController = TextEditingController();
  final TextEditingController _wifiPassController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _contactEmailController = TextEditingController();
  final TextEditingController _locLatController = TextEditingController();
  final TextEditingController _locLngController = TextEditingController();
  final TextEditingController _eventTitleController = TextEditingController();
  final TextEditingController _cryptoAddressController = TextEditingController();
  final TextEditingController _cryptoAmountController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  
  final List<String> _templates = [
    'URL',
    'Text',
    'WiFi',
    'Contact',
    'Email',
    'Location',
    'SMS',
    'Event',
    'Crypto',
  ];

  @override
  void dispose() {
    for (var c in [
      _dataController, _wifiSsidController, _wifiPassController,
      _contactNameController, _contactPhoneController, _contactEmailController,
      _locLatController, _locLngController, _eventTitleController,
      _cryptoAddressController, _cryptoAmountController,
      _subjectController, _messageController
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _clearAllControllers() {
    for (var c in [
      _dataController, _wifiSsidController, _wifiPassController,
      _contactNameController, _contactPhoneController, _contactEmailController,
      _locLatController, _locLngController, _eventTitleController,
      _cryptoAddressController, _cryptoAmountController,
      _subjectController, _messageController
    ]) {
      c.clear();
    }
  }

  final List<Color> _availableColors = [
    Colors.black,
    Colors.blue.shade800,
    Colors.red.shade800,
    Colors.purple.shade800,
    Colors.teal.shade800,
    Colors.orange.shade800,
  ];

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile != null) {
      setState(() {
        _logoPath = xFile.path;
      });
    }
  }

  void _updateQrData() {
    setState(() {
      if (_selectedTemplate == 'Free Input' || _selectedTemplate == 'Text' || _selectedTemplate == 'URL') {
        _qrData = _dataController.text;
      } else if (_selectedTemplate == 'WiFi') {
        _qrData = 'WIFI:T:WPA;S:${_wifiSsidController.text};P:${_wifiPassController.text};;';
      } else if (_selectedTemplate == 'Email') {
        _qrData = 'MATMSG:TO:${_dataController.text};SUB:${_subjectController.text};BODY:${_messageController.text};;';
      } else if (_selectedTemplate == 'Contact') {
        _qrData = 'MECARD:N:${_contactNameController.text};TEL:${_contactPhoneController.text};EMAIL:${_contactEmailController.text};;';
      } else if (_selectedTemplate == 'Location') {
        _qrData = 'geo:${_locLatController.text},${_locLngController.text}';
      } else if (_selectedTemplate == 'SMS') {
        _qrData = 'SMSTO:${_subjectController.text}:${_messageController.text}';
      } else if (_selectedTemplate == 'Event') {
        _qrData = 'BEGIN:VEVENT\nSUMMARY:${_eventTitleController.text}\nEND:VEVENT';
      } else if (_selectedTemplate == 'Crypto') {
        _qrData = 'bitcoin:${_cryptoAddressController.text}?amount=${_cryptoAmountController.text}';
      }
    });
  }

  Future<void> _handleExport() async {
    if (_qrData.trim().isEmpty) return;

    // ═══ 🛡️ AntiGravity Security Check before export ═══
    final securityResult = SecurityHelper.analyzeContent(_qrData);
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
      setState(() => _qrData = securityResult.sanitizedContent ?? _qrData);
    }
    // ═══ End Security Check ═══
    
    // Add to History
    await HistoryManager.addHistory(HistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'QR',
      content: _qrData,
      timestamp: DateTime.now(),
    ));

    if (mounted) {
      final format = _selectedFormat.toLowerCase();
      if (format == 'pdf') {
        ExportHelper.exportPDF(
          context: context,
          key: _globalKey,
          fileName: 'qrcode',
          isShare: true,
        );
      } else if (format == 'svg') {
        ExportHelper.exportSVG(
          context: context,
          qrData: _qrData,
          fileName: 'qrcode',
        );
      } else {
        ExportHelper.exportBoundary(
          context: context,
          key: _globalKey,
          fileName: 'qrcode',
          ext: format,
          isShare: true,
        );
      }
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
              tag: 'qr_preview',
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
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: QrImageView(
                          data: _qrData.isEmpty ? ' ' : _qrData,
                          version: QrVersions.auto,
                          size: _sizeMap[_selectedSize] ?? 200.0,
                          eyeStyle: QrEyeStyle(
                            eyeShape: _isRoundEye ? QrEyeShape.circle : QrEyeShape.square,
                            color: _qrColor,
                          ),
                          dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: _isRoundEye ? QrDataModuleShape.circle : QrDataModuleShape.square,
                            color: _qrColor,
                          ),
                          embeddedImage: _logoPath != null ? FileImage(File(_logoPath!)) : null,
                          embeddedImageStyle: const QrEmbeddedImageStyle(
                            size: Size(40, 40),
                          ),
                          errorStateBuilder: (cxt, err) => const Center(
                            child: Text('Error rendering QR', textAlign: TextAlign.center),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Content Templates List
            Text(
              loc(context, 'content_type'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment(0.85, 0),
                  end: Alignment.centerRight,
                  colors: [Colors.white, Colors.transparent],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _templates.length,
                  padding: const EdgeInsets.only(right: 24),
                  itemBuilder: (context, index) {
                    final t = _templates[index];
                    final isSelected = _selectedTemplate == t;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(t),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedTemplate = t;
                              _clearAllControllers();
                              _updateQrData();
                            });
                          }
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

            // Dynamic Inputs based on Template
            if (_selectedTemplate == 'WiFi') ...[
              TextFormField(
                controller: _wifiSsidController,
                decoration: const InputDecoration(labelText: 'Network Name (SSID)', prefixIcon: Icon(Icons.wifi)),
                onChanged: (_) => _updateQrData(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _wifiPassController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
                onChanged: (_) => _updateQrData(),
              ),
            ] else if (_selectedTemplate == 'Contact') ...[
              TextFormField(
                controller: _contactNameController,
                decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person)),
                onChanged: (_) => _updateQrData(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone)),
                onChanged: (_) => _updateQrData(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                onChanged: (_) => _updateQrData(),
              ),
            ] else if (_selectedTemplate == 'Location') ...[
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _locLatController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Latitude', prefixIcon: Icon(Icons.map)),
                  onChanged: (_) => _updateQrData(),
                )),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(
                  controller: _locLngController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Longitude', prefixIcon: Icon(Icons.location_on)),
                  onChanged: (_) => _updateQrData(),
                )),
              ]),
            ] else if (_selectedTemplate == 'Event') ...[
              TextFormField(
                controller: _eventTitleController,
                decoration: const InputDecoration(labelText: 'Event Title', prefixIcon: Icon(Icons.event)),
                onChanged: (_) => _updateQrData(),
              ),
            ] else if (_selectedTemplate == 'Crypto') ...[
              TextFormField(
                controller: _cryptoAddressController,
                decoration: const InputDecoration(labelText: 'Crypto Address', prefixIcon: Icon(Icons.currency_bitcoin)),
                onChanged: (_) => _updateQrData(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cryptoAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (Optional)', prefixIcon: Icon(Icons.attach_money)),
                onChanged: (_) => _updateQrData(),
              ),
            ] else if (_selectedTemplate == 'Email' || _selectedTemplate == 'SMS') ...[
              TextFormField(
                controller: _selectedTemplate == 'Email' ? _dataController : _subjectController,
                decoration: InputDecoration(
                  labelText: _selectedTemplate == 'Email' ? 'Email Address' : 'Phone Number',
                  prefixIcon: Icon(_selectedTemplate == 'Email' ? Icons.email : Icons.phone),
                ),
                onChanged: (_) => _updateQrData(),
              ),
              if (_selectedTemplate == 'Email') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(labelText: 'Subject', prefixIcon: Icon(Icons.subject)),
                  onChanged: (_) => _updateQrData(),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Message', prefixIcon: Icon(Icons.message)),
                onChanged: (_) => _updateQrData(),
              ),
            ] else ...[
               TextFormField(
                controller: _dataController,
                style: const TextStyle(fontSize: 14),
                scrollPhysics: const BouncingScrollPhysics(),
                decoration: InputDecoration(
                  labelText: _selectedTemplate,
                  hintText: _selectedTemplate == 'URL' ? 'https://example.com' : 'Enter text here...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: Icon(_selectedTemplate == 'URL' ? Icons.link : Icons.edit),
                  suffixIcon: _dataController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        tooltip: 'Clear',
                        onPressed: () {
                          _dataController.clear();
                          _updateQrData();
                        },
                      )
                    : null,
                ),
                onChanged: (_) => _updateQrData(),
                maxLines: _selectedTemplate == 'Free Input' ? 3 : 1,
              ),
            ],

            const SizedBox(height: 24),
            
            // Design Customizations
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc(context, 'colors'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Color Selection
                  SizedBox(
                    height: 48,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _availableColors.length,
                      itemBuilder: (context, index) {
                        final color = _availableColors[index];
                        final isSelected = _qrColor == color;
                        return GestureDetector(
                          onTap: () => setState(() => _qrColor = color),
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 48,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                              border: isSelected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 24)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Shape Selection
                  Text(
                    loc(context, 'eye_shape'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(loc(context, 'square_eyes')),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        selected: !_isRoundEye,
                        onSelected: (val) => setState(() => _isRoundEye = !val),
                        selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      ),
                      ChoiceChip(
                        label: Text(loc(context, 'round_eyes')),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        selected: _isRoundEye,
                        onSelected: (val) => setState(() => _isRoundEye = val),
                        selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // QR Code Size
                  Text(
                    loc(context, 'qr_size'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _sizeMap.keys.map((size) {
                      final isSelected = _selectedSize == size;
                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              size == 'Small' ? Icons.photo_size_select_small
                                : size == 'Medium' ? Icons.photo_size_select_actual
                                : Icons.photo_size_select_large,
                              size: 16,
                              color: isSelected ? Theme.of(context).colorScheme.primary : null,
                            ),
                            const SizedBox(width: 4),
                            Text(size),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) setState(() => _selectedSize = size);
                        },
                        selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Download Format
                  Text(
                    loc(context, 'download_format'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _formats.map((format) {
                      final isSelected = _selectedFormat == format;
                      return ChoiceChip(
                        label: Text(format),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) setState(() => _selectedFormat = format);
                        },
                        selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        avatar: Icon(
                          format == 'PDF' ? Icons.picture_as_pdf
                            : format == 'SVG' ? Icons.draw
                            : Icons.image,
                          size: 18,
                          color: isSelected ? Theme.of(context).colorScheme.primary : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Pick Logo (Secondary - Optional)
                  OutlinedButton.icon(
                    onPressed: _pickLogo,
                    icon: Icon(Icons.add_photo_alternate, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    label: Text(
                      _logoPath != null ? '${loc(context, 'pick_logo')} ✓' : loc(context, 'pick_logo'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 42),
                      side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Export Button (Primary - Main CTA)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: _qrData.isEmpty
                    ? [Colors.grey.shade400, Colors.grey.shade500]
                    : [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.tertiary],
                ),
                boxShadow: _qrData.isNotEmpty ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ] : null,
              ),
              child: ElevatedButton.icon(
                onPressed: _qrData.isEmpty ? null : _handleExport,
                icon: Icon(
                  _selectedFormat == 'PDF' ? Icons.picture_as_pdf
                    : _selectedFormat == 'SVG' ? Icons.draw
                    : Icons.download_rounded,
                  size: 22,
                ),
                label: Text(
                  '${loc(context, 'export')} ($_selectedFormat)',
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
