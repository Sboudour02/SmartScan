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
    id: json['id'],
    type: json['type'],
    content: json['content'],
    format: json['format'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

class HistoryManager {
  static const String _key = 'smartscan_history';

  static Future<List<HistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_key);
    if (data == null) return [];
    
    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((e) => HistoryItem.fromJson(e)).toList();
  }

  static Future<void> addHistory(HistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    List<HistoryItem> history = await getHistory();
    
    // Add to top
    history.insert(0, item);

    // Keep only last 10
    if (history.length > 10) {
      history = history.sublist(0, 10);
    }

    await prefs.setString(_key, jsonEncode(history.map((e) => e.toJson()).toList()));
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> deleteHistory(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<HistoryItem> history = await getHistory();
    history.removeWhere((item) => item.id == id);
    await prefs.setString(_key, jsonEncode(history.map((e) => e.toJson()).toList()));
  }
}
