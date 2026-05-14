import 'package:flutter/foundation.dart';

/// Liste davet bağlantısı için ürün kuralları (Supabase tarafında da RLS/trigger ile korunmalı).
///
/// - [maxJoinCount]: Bu token/link ile **en fazla kaç benzersiz kullanıcı** listeye
///   katılabilir (sunucu sayacı ile enforced).
/// - [expiresAt]: Dolu ise bu tarih/saatten sonra bağlantı geçersiz; `null` ise süresiz.
@immutable
final class InviteLinkRules {
  const InviteLinkRules({
    required this.maxJoinCount,
    this.expiresAt,
  }) : assert(maxJoinCount > 0, 'En az 1 katılımcı kotası olmalı.');

  /// Bu davet ile izin verilen benzersiz kullanıcı sayısı üst sınırı.
  final int maxJoinCount;

  /// İsteğe bağlı son kullanma zamanı (UTC önerilir).
  final DateTime? expiresAt;

  bool get isNeverExpires => expiresAt == null;

  /// Şu an için bağlantının süresi dolmuş mu (istemci tarafı ön kontrol).
  bool isExpiredAt(DateTime nowUtc) {
    final end = expiresAt;
    if (end == null) return false;
    return !nowUtc.isBefore(end);
  }

  InviteLinkRules copyWith({
    int? maxJoinCount,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
  }) {
    return InviteLinkRules(
      maxJoinCount: maxJoinCount ?? this.maxJoinCount,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is InviteLinkRules &&
        other.maxJoinCount == maxJoinCount &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode => Object.hash(maxJoinCount, expiresAt);
}
