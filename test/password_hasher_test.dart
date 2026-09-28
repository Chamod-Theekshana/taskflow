import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/features/auth/data/datasources/auth_local_data_source.dart';

void main() {
  test('hashes are salted and verifiable', () {
    final a = PasswordHasher.hash('Secret123');
    final b = PasswordHasher.hash('Secret123');
    expect(a, isNot(b)); // different salts
    expect(PasswordHasher.verify('Secret123', a), isTrue);
    expect(PasswordHasher.verify('wrong', a), isFalse);
    expect(PasswordHasher.isLegacy(a), isFalse);
  });

  test('legacy unsalted SHA-256 hashes are still accepted', () {
    final legacy = sha256.convert(utf8.encode('Secret123')).toString();
    expect(PasswordHasher.isLegacy(legacy), isTrue);
    expect(PasswordHasher.verify('Secret123', legacy), isTrue);
    expect(PasswordHasher.verify('nope', legacy), isFalse);
  });

  test('e-mail addresses are normalised', () {
    expect(
      AuthLocalDataSourceImpl.normalizeEmail('  Alex@Example.COM '),
      'alex@example.com',
    );
  });
}
