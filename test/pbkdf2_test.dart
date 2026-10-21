import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maxsecurepass/services/pbkdf2.dart';

String hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('vecteurs de référence (RFC 7914, section 11)', () {
    expect(
      hex(pbkdf2HmacSha256(utf8.encode('passwd'), utf8.encode('salt'), 1, 64)),
      '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
      '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
    );
    expect(
      hex(pbkdf2HmacSha256(utf8.encode('Password'), utf8.encode('NaCl'), 80000, 64)),
      '4ddcd8f60b98be21830cee5ef22701f9641a4418d04c0414aeff08876b34ab56'
      'a1d425a1225833549adb841b51c9b3176a272bdebba1d078478f62b397f33c8d',
    );
  });

  test('identique à l’implémentation de référence du package cryptography', () async {
    final random = Random(42);
    List<int> bytes(int n) => List.generate(n, (_) => random.nextInt(256));
    // Mots de passe vides, courts, et plus longs qu'un bloc (haché au préalable).
    for (final (passwordLength, saltLength, iterations, keyLength) in [
      (0, 16, 3, 32),
      (12, 16, 1000, 32),
      (64, 0, 7, 20),
      (65, 16, 50, 70),
      (200, 100, 2, 32),
    ]) {
      final password = bytes(passwordLength);
      final salt = bytes(saltLength);
      final expected = await DartPbkdf2(
        macAlgorithm: const DartHmac(DartSha256()),
        iterations: iterations,
        bits: keyLength * 8,
      ).deriveKey(secretKey: SecretKeyData(password), nonce: salt);
      expect(
        hex(pbkdf2HmacSha256(password, salt, iterations, keyLength)),
        hex(await expected.extractBytes()),
        reason: 'mot de passe=$passwordLength sel=$saltLength itérations=$iterations',
      );
    }
  });
}
