/// Görünen ad uzunluk sınırı (UI + backend doğrulamasında ortak kullanın).
const int kDisplayNameMaxLength = 40;

/// Boşluğu kırpar; fazla uzunsa keser.
String normalizeDisplayName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.length <= kDisplayNameMaxLength) return trimmed;
  return trimmed.substring(0, kDisplayNameMaxLength);
}

bool isValidDisplayName(String normalized) {
  return normalized.isNotEmpty;
}
