import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxsecurepass/services/password_generator.dart';

void main() {
  test('respecte la longueur et inclut chaque catégorie demandée', () {
    for (var i = 0; i < 200; i++) {
      final password = generatePassword(const PasswordOptions(length: 12), random: Random(i));
      expect(password, hasLength(12));
      expect(password, matches(RegExp('[a-z]')));
      expect(password, matches(RegExp('[A-Z]')));
      expect(password, matches(RegExp('[0-9]')));
      expect(password, matches(RegExp('[^a-zA-Z0-9]')));
    }
  });

  test("n'utilise que les catégories demandées", () {
    final password = generatePassword(
      const PasswordOptions(length: 40, lowercase: false, uppercase: false, symbols: false),
    );
    expect(password, matches(RegExp(r'^[0-9]{40}$')));
  });

  test('refuse une configuration sans catégorie', () {
    expect(
      () => generatePassword(
        const PasswordOptions(lowercase: false, uppercase: false, digits: false, symbols: false),
      ),
      throwsArgumentError,
    );
  });

  test('évalue la robustesse', () {
    expect(passwordStrength(''), PasswordStrength.veryWeak);
    expect(passwordStrength('abc'), PasswordStrength.veryWeak);
    expect(passwordStrength('azerty'), PasswordStrength.weak);
    expect(passwordStrength('Azerty12'), PasswordStrength.medium);
    expect(
      passwordStrength(generatePassword(const PasswordOptions())),
      PasswordStrength.veryStrong,
    );
  });
}
