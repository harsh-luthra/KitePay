import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class NotificationItem {
  final String id;        // unique; e.g., qrId or uuid
  final String title;     // e.g., 'QR Work Started'
  final String subtitle;  // e.g., qr.qrId or amount info
  final DateTime at;

  NotificationItem({required this.id, required this.title, required this.subtitle, required this.at});

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'at': at.toIso8601String(),
  };

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    subtitle: j['subtitle'] as String? ?? '',
    at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
  );
}

class NotificationStore {
  static const _key = 'qr_alert_notifications_v1';
  static const _cap = 100; // keep last 100

  final List<NotificationItem> _items = [];
  int get count => _items.length;
  List<NotificationItem> get items => List.unmodifiable(_items);

  Timer? _saveTimer;
  bool _dirty = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key);
    if (s == null) return;
    final list = (jsonDecode(s) as List).cast<Map<String, dynamic>>();
    _items
      ..clear()
      ..addAll(list.map(NotificationItem.fromJson));
  }

  Future<void> _persist() async {
    if (!_dirty) return;
    _dirty = false;
    final prefs = await SharedPreferences.getInstance();
    final s = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString(_key, s);
  }

  void _scheduleSave() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _persist);
  }

  Future<void> add(NotificationItem it) async {
    _items.insert(0, it);
    if (_items.length > _cap) _items.removeRange(_cap, _items.length);
    _scheduleSave();
  }

  Future<void> clear() async {
    _items.clear();
    _saveTimer?.cancel();
    _dirty = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, '[]');
  }
}
