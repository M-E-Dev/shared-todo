import 'package:flutter/foundation.dart';

/// Oturumdaki kullanıcı (anonim dahil). Kişisel veri olarak yalnızca görünen ad tutulur.
@immutable
final class AuthUser {
  const AuthUser({
    required this.id,
    this.displayName,
  });

  final String id;
  final String? displayName;

  bool get hasDisplayName =>
      displayName != null && displayName!.trim().isNotEmpty;

  AuthUser copyWith({
    String? id,
    String? displayName,
    bool clearDisplayName = false,
  }) {
    return AuthUser(
      id: id ?? this.id,
      displayName: clearDisplayName ? null : (displayName ?? this.displayName),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AuthUser &&
        other.id == id &&
        other.displayName == displayName;
  }

  @override
  int get hashCode => Object.hash(id, displayName);
}
