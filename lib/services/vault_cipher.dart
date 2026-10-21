import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'pbkdf2.dart';

/// Levée quand une clé ne déchiffre pas : mot de passe maître ou réponses
/// incorrects, ou fichier du coffre altéré (l'authentification AES-GCM
/// échoue).
class WrongPasswordException implements Exception {
  const WrongPasswordException();
}

/// Résultat d'un chiffrement AES-256-GCM.
class Sealed {
  const Sealed(this.nonce, this.cipherText, this.mac);

  factory Sealed.fromJson(Map<String, dynamic> json) => Sealed(
    base64Decode(json['nonce'] as String),
    base64Decode(json['ciphertext'] as String),
    base64Decode(json['mac'] as String),
  );

  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;

  Map<String, dynamic> toJson() => {
    'nonce': base64Encode(nonce),
    'ciphertext': base64Encode(cipherText),
    'mac': base64Encode(mac),
  };
}

/// Primitives cryptographiques du coffre.
///
/// Le coffre est chiffré par une **clé de coffre** aléatoire de 256 bits.
/// Cette clé est elle-même chiffrée (« verrouillée ») par une clé dérivée du
/// mot de passe maître, et par une clé dérivée des réponses de récupération.
/// Changer ou réinitialiser le mot de passe maître ne fait que reverrouiller
/// la clé de coffre : les données ne sont jamais rechiffrées ni perdues.
class VaultCipher {
  VaultCipher({
    this.iterations = defaultIterations,
    this.recoveryIterations = defaultRecoveryIterations,
  });

  /// Recommandation OWASP pour PBKDF2-HMAC-SHA256.
  static const defaultIterations = 600000;

  /// Par réponse ; les trois sont calculées en parallèle, soit 600 000
  /// itérations au total pour qui veut tester une combinaison.
  static const defaultRecoveryIterations = 200000;

  final int iterations;
  final int recoveryIterations;
  final _aes = AesGcm.with256bits();

  static List<int> randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  SecretKey newDataKey() => SecretKey(randomBytes(32));

  /// Clé dérivée du mot de passe maître (PBKDF2-HMAC-SHA256).
  Future<SecretKey> deriveMasterKey(String password, List<int> salt, int iterations) async {
    // PBKDF2 est volontairement lent : on le calcule hors du thread UI.
    final bytes = await Isolate.run(
      () => pbkdf2HmacSha256(utf8.encode(password), salt, iterations, 32),
    );
    return SecretKey(bytes);
  }

  /// Clé dérivée des trois réponses déjà normalisées, chacune avec son
  /// propre sel, et du secret matériel du téléphone ([deviceSecret]).
  ///
  /// Les trois dérivations sont combinées en une seule clé (HKDF-SHA256) :
  /// on ne peut pas vérifier une réponse isolément, ni deviner les réponses
  /// une par une.
  Future<SecretKey> deriveRecoveryKey(
    List<String> answers,
    List<List<int>> salts,
    int iterations,
    List<int> deviceSecret,
  ) async {
    assert(answers.length == salts.length);
    final parts = await Future.wait([
      for (var i = 0; i < answers.length; i++)
        Isolate.run(() => pbkdf2HmacSha256(utf8.encode(answers[i]), salts[i], iterations, 32)),
    ]);
    return Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey([for (final p in parts) ...p, ...deviceSecret]),
      nonce: utf8.encode('maxsecurepass-recovery'),
      info: utf8.encode('recovery-key-v1'),
    );
  }

  /// Chiffre [clear] ; [context] est authentifié (données associées) pour
  /// lier le résultat à son usage et à son coffre.
  Future<Sealed> seal(List<int> clear, SecretKey key, String context) async {
    final box = await _aes.encrypt(clear, secretKey: key, aad: utf8.encode(context));
    return Sealed(box.nonce, box.cipherText, box.mac.bytes);
  }

  /// Lève [WrongPasswordException] si la clé ou le contexte ne correspondent
  /// pas, ou si les données ont été modifiées.
  Future<List<int>> open(Sealed sealed, SecretKey key, String context) async {
    try {
      return await _aes.decrypt(
        SecretBox(sealed.cipherText, nonce: sealed.nonce, mac: Mac(sealed.mac)),
        secretKey: key,
        aad: utf8.encode(context),
      );
    } on SecretBoxAuthenticationError {
      throw const WrongPasswordException();
    }
  }

  /// Lit un coffre au format 1 (avant la récupération par questions), où la
  /// clé dérivée du mot de passe chiffrait directement les données.
  Future<String> decryptLegacy(Map<String, dynamic> json, String password) async {
    final key = await deriveMasterKey(
      password,
      base64Decode(json['salt'] as String),
      json['iterations'] as int,
    );
    try {
      final clear = await _aes.decrypt(
        SecretBox(
          base64Decode(json['ciphertext'] as String),
          nonce: base64Decode(json['nonce'] as String),
          mac: Mac(base64Decode(json['mac'] as String)),
        ),
        secretKey: key,
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw const WrongPasswordException();
    }
  }
}
