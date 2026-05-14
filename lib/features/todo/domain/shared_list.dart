import 'package:flutter/foundation.dart';

/// `public.lists` satırının domain karşılığı.
@immutable
final class SharedList {
  const SharedList({
    required this.id,
    required this.title,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String createdBy;
  final DateTime createdAt;

  factory SharedList.fromJson(Map<String, dynamic> json) {
    return SharedList(
      id: json['id'] as String,
      title: json['title'] as String,
      createdBy: json['created_by'] as String,
      createdAt: _parseTs(json['created_at']),
    );
  }

  static DateTime _parseTs(Object? raw) {
    if (raw is String) {
      return DateTime.tryParse(raw)?.toUtc() ?? DateTime.now().toUtc();
    }
    if (raw is DateTime) {
      return raw.toUtc();
    }
    return DateTime.now().toUtc();
  }

  @override
  bool operator ==(Object other) {
    return other is SharedList &&
        other.id == id &&
        other.title == title &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(id, title, createdBy, createdAt);
}
