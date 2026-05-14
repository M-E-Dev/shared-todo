import 'package:flutter/material.dart';

enum ListSortDirection {
  newestFirst,
  oldestFirst,
  titleAsc;

  static ListSortDirection fromString(String? raw) {
    return switch (raw) {
      'oldest_first' => oldestFirst,
      'title_asc' => titleAsc,
      _ => newestFirst,
    };
  }

  String toJson() => switch (this) {
        newestFirst => 'newest_first',
        oldestFirst => 'oldest_first',
        titleAsc => 'title_asc',
      };

  String get label => switch (this) {
        newestFirst => 'Yeniden eskiye',
        oldestFirst => 'Eskiden yeniye',
        titleAsc => 'A → Z',
      };
}

/// `public.lists` satırının domain karşılığı.
@immutable
final class SharedList {
  const SharedList({
    required this.id,
    required this.title,
    required this.createdBy,
    required this.createdAt,
    this.color = const Color(0xFF6366F1),
    this.sortDirection = ListSortDirection.newestFirst,
  });

  final String id;
  final String title;
  final String createdBy;
  final DateTime createdAt;
  final Color color;
  final ListSortDirection sortDirection;

  factory SharedList.fromJson(Map<String, dynamic> json) {
    return SharedList(
      id: json['id'] as String,
      title: json['title'] as String,
      createdBy: json['created_by'] as String,
      createdAt: _parseTs(json['created_at']),
      color: _parseColor(json['color'] as String?),
      sortDirection:
          ListSortDirection.fromString(json['sort_direction'] as String?),
    );
  }

  static Color _parseColor(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const Color(0xFF6366F1);
    }
    final hex = raw.startsWith('#') ? raw.substring(1) : raw;
    final padded = hex.length == 6 ? 'FF$hex' : hex;
    return Color(int.tryParse(padded, radix: 16) ?? 0xFF6366F1).withValues(alpha: 1);
  }

  static String colorToHex(Color c) {
    final int argb = c.toARGB32();
    return '#${argb.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
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

  SharedList copyWith({
    Color? color,
    ListSortDirection? sortDirection,
    String? title,
  }) {
    return SharedList(
      id: id,
      title: title ?? this.title,
      createdBy: createdBy,
      createdAt: createdAt,
      color: color ?? this.color,
      sortDirection: sortDirection ?? this.sortDirection,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SharedList &&
        other.id == id &&
        other.title == title &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt &&
        other.color == color &&
        other.sortDirection == sortDirection;
  }

  @override
  int get hashCode =>
      Object.hash(id, title, createdBy, createdAt, color, sortDirection);
}
