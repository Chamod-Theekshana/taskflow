import 'dart:math';

final _random = Random.secure();

/// A random (version 4) UUID, e.g. `3f2b8c1e-5d7a-4c55-9f3e-8a1b2c3d4e5f`.
///
/// Tasks get one when they are created so they keep the same identity on
/// every device and on the server, even when created offline.
String newUuid() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
