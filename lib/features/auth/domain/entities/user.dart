class User {
  final String id;
  final String fullName;
  final String email;

  /// When the account was created on the server.
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.fullName,
    required this.email,
    this.createdAt,
  });

  /// Up to two initials for the avatar, e.g. `Alex Morgan` -> `AM`.
  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return email.isNotEmpty ? email[0].toUpperCase() : '?';
    }
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  DateTime? get memberSince => createdAt;
}
