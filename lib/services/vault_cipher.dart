import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'pbkdf2.dart';

/// Levée quand le mot de passe maître est incorrect ou que le fichier
/// du coffre a été altéré (l'authentification AES-GCM échoue).
class WrongPasswordException implements Exception {
  const WrongPasswordException();
}

/// Clé dérivée du mot de passe maître, avec les paramètres nécessaires
/// pour rechiffrer le coffre sans redemander le mot de passe.
class VaultKey {
  VaultKey(this.secretKey, this.salt, this.iterations);

  final SecretKey secretKey;
  final List<int> salt;
  final int iterations;
}

/// Chiffre le coffre avec AES-256-GCM. La clé est dérivée du mot de passe
/// maître par PBKDF2-HMAC-SHA256 avec un sel aléatoire.
class VaultCipher {
  VaultCipher({this.iterations = defaultIterations});

  /// Recommandation OWASP pour PBKDF2-HMAC-SHA256.
  static const defaultIterations = 600000;
  static const formatVersion = 1;

  final int iterations;
  final _aes = AesGcm.with256bits();

  /// Crée une nouvelle clé (nouveau sel) pour [password].
  Future<VaultKey> newKey(String password) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    return _deriveKey(password, salt, iterations);
  }

  Future<String> encrypt(String plaintext, VaultKey key) async {
    final box = await _aes.encrypt(utf8.encode(plaintext), secretKey: key.secretKey);
    return jsonEncode({
      'version': formatVersion,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': key.iterations,
      'salt': base64Encode(key.salt),
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  /// Déchiffre [data] et renvoie le texte clair ainsi que la clé dérivée.
  Future<(String, VaultKey)> decrypt(String data, String password) async {
    final json = _parse(data);
    final key = await _deriveKey(
      password,
      base64Decode(json['salt'] as String),
      json['iterations'] as int,
    );
    return (await _open(json, key), key);
  }

  /// Déchiffre [data] avec une clé déjà dérivée (déverrouillage par le
  /// téléphone), sans recalculer PBKDF2.
  Future<(String, VaultKey)> decryptWithKey(String data, List<int> keyBytes) async {
    final json = _parse(data);
    final key = VaultKey(
      SecretKey(keyBytes),
      base64Decode(json['salt'] as String),
      json['iterations'] as int,
    );
    return (await _open(json, key), key);
  }

  Map<String, dynamic> _parse(String data) {
    final json = jsonDecode(data) as Map<String, dynamic>;
    if (json['version'] != formatVersion) {
      throw FormatException('Version de coffre non prise en charge : ${json['version']}');
    }
    return json;
  }

  Future<String> _open(Map<String, dynamic> json, VaultKey key) async {
    final box = SecretBox(
      base64Decode(json['ciphertext'] as String),
      nonce: base64Decode(json['nonce'] as String),
      mac: Mac(base64Decode(json['mac'] as String)),
    );
    try {
      return utf8.decode(await _aes.decrypt(box, secretKey: key.secretKey));
    } on SecretBoxAuthenticationError {
      throw const WrongPasswordException();
    }
  }

  static Future<VaultKey> _deriveKey(String password, List<int> salt, int iterations) async {
    // PBKDF2 est volontairement lent : on le calcule hors du thread UI.
    final bytes = await Isolate.run(
      () => pbkdf2HmacSha256(utf8.encode(password), salt, iterations, 32),
    );
    return VaultKey(SecretKey(bytes), salt, iterations);
  }
}
