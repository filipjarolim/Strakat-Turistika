import 'dart:convert';

/// Represents a single in-app notification delivered to the user.
class NotificationItem {
  final String id; // unique id (e.g., messageId)
  final String title;
  final String body;
  final String type; // e.g., activity_approved, activity_rejected, generic
  final DateTime timestamp;
  final Map<String, dynamic>? data; // optional payload (e.g., visitId)
  bool read;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.data,
    this.read = false,
  });

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    return NotificationItem(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: map['type'] as String? ?? 'generic',
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      data: map['data'] is Map<String, dynamic>
          ? (map['data'] as Map<String, dynamic>)
          : (map['data'] != null ? Map<String, dynamic>.from(jsonDecode(map['data'])) : null),
      read: map['read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'data': data,
      'read': read,
    };
  }
}


