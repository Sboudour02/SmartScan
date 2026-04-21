import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import 'localization.dart';

class UpdateManager {
  static const String _owner = 'Sboudour02';
  static const String _repo = 'SmartScan';
  static const String _apiUrl = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  static Future<void> checkAndPromptUpdate(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final latestVersion = data['tag_name'].toString().replaceAll('v', '');
      final downloadUrl = _getApkDownloadUrl(data['assets']);
      final releaseNotes = data['body'] ?? '';

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isNewer(latestVersion, currentVersion) && downloadUrl != null) {
        if (!context.mounted) return;
        _showUpdateDialog(context, latestVersion, downloadUrl, releaseNotes);
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  static String? _getApkDownloadUrl(List<dynamic> assets) {
    for (var asset in assets) {
      if (asset['name'].toString().endsWith('.apk')) {
        return asset['browser_download_url'];
      }
    }
    return null;
  }

  static bool _isNewer(String latest, String current) {
    try {
      final latestParts = latest.split('+');
      final currentParts = current.split('+');
      
      final vLatest = latestParts[0].split('.');
      final vCurrent = currentParts[0].split('.');
      
      for (var i = 0; i < vLatest.length; i++) {
        final l = int.parse(vLatest[i]);
        final c = i < vCurrent.length ? int.parse(vCurrent[i]) : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      
      if (latestParts.length > 1 && currentParts.length > 1) {
        final bLatest = int.parse(latestParts[1]);
        final bCurrent = int.parse(currentParts[1]);
        return bLatest > bCurrent;
      }
    } catch (e) {
      return latest != current;
    }
    return false;
  }

  static void _showUpdateDialog(BuildContext context, String version, String url, String notes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UpdateDialog(
        version: version,
        url: url,
        notes: notes,
      ),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final String version;
  final String url;
  final String notes;

  const _UpdateDialog({
    required this.version,
    required this.url,
    required this.notes,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double _progress = 0;
  bool _isDownloading = false;
  String _status = '';

  void _startUpdate() {
    setState(() {
      _isDownloading = true;
    });

    try {
      OtaUpdate().execute(widget.url, destinationFilename: 'SmartScan_Update.apk').listen(
        (OtaEvent event) {
          setState(() {
            _status = event.status.toString();
            if (event.value != null) {
              _progress = double.parse(event.value!) / 100;
            }
          });
          
          if (event.status == OtaStatus.INSTALLING) {
            Navigator.of(context).pop();
          }
        },
        onError: (error) {
          setState(() {
            _isDownloading = false;
            _status = 'Error: $error';
          });
        },
      );
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Provider.of<LocaleProvider>(context, listen: false).locale.languageCode == 'ar';

    return AlertDialog(
      title: Text(isArabic ? 'تحديث جديد متوفر' : 'New Update Available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${isArabic ? 'الإصدار' : 'Version'}: ${widget.version}'),
          if (widget.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(),
            Text(widget.notes),
          ],
          if (_isDownloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text('${(_progress * 100).toStringAsFixed(0)}%'),
          ],
        ],
      ),
      actions: _isDownloading
          ? []
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(isArabic ? 'لاحقاً' : 'Later'),
              ),
              ElevatedButton(
                onPressed: _startUpdate,
                child: Text(isArabic ? 'تحديث الآن' : 'Update Now'),
              ),
            ],
    );
  }
}
