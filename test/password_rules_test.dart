import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/features/auth/presentation/screens/signup_screen.dart';

void main() {
  test('a password needs 8+ characters, mixed case and a number', () {
    expect(passwordMeetsRules('Secret12'), isTrue);
    expect(passwordMeetsRules('secret12'), isFalse);
    expect(passwordMeetsRules('SECRET12'), isFalse);
    expect(passwordMeetsRules('SecretAb'), isFalse);
    expect(passwordMeetsRules('Sec12'), isFalse);
  });

  test('strength score counts length, case, digits and extras', () {
    expect(passwordScore(''), 0);
    expect(passwordScore('abc'), 0);
    expect(passwordScore('abcdefgh'), 1);
    expect(passwordScore('Abcdefgh'), 2);
    expect(passwordScore('Abcdefg1'), 3);
    expect(passwordScore('Abcdefg1!'), 4);
    expect(passwordScore('Abcdefghijk1'), 4);
  });
}
