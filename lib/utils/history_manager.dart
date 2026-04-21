import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryItem {
  final String id;
  final String type; // 'QR' or 'Barcode'
  final String content;
  final String? format; // Only for Barcode e.g., 'Code 128'
  final DateTime timestamp;

  HistoryItem({
    required this.id,
    required this.type,
    required this.content,
    this.format,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'content': content,
    'format': format,
    'timestamp': timestamp.toIso8601String(),
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    type: json['type']?.toString() ?? 'QR',
    content: json['content']?.toString() ?? '',
    format: json['format']?.toString(),
    timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
  );
}

class HistoryManager {
  static const String _key = 'smartscan_history';
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<List<HistoryItem>> getHistory() async {
    final prefs = await _instance;
    final String? data = prefs.getString(_key);
    if (data == null) return [];
    
    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((e) => HistoryItem.fromJson(e)).toList();
  }

  static Future<void> addHistory(HistoryItem item) async {
    List<HistoryItem> history = await getHistory();
    
    // Add to top
    history.insert(0, item);

    // Keep only last 10
    if (history.length > 10) {
      history = history.sublist(0, 10);
    }

    final prefs = await _instance;

    await prefs.setString(_key, jsonEncode(history.map((e) => e.toJson()).toList()));
  }

  static Future<void> clearHistory() async {
    final prefs = await _instance;
    await prefs.remove(_key);
  }

  static Future<void> deleteHistory(String id) async {
    final prefs = await _instance;
    List<HistoryItem> history = await getHistory();
    history.removeWhere((item) => item.id == id);
    await prefs.setString(_key, jsonEncode(history.map((e) => e.toJson()).toList()));
  }

  static Future<void> deleteSelectedHistory(List<String> ids) async {
    if (ids.isEmpty) return;
    final prefs = await _instance;
    List<HistoryItem> history = await getHistory();
    history.removeWhere((item) => ids.contains(item.id));
    await prefs.setString(_key, jsonEncode(history.map((e) => e.toJson()).toList()));
  }
}
