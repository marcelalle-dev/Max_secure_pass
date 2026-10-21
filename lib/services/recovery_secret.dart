import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'device_unlock.dart';
import 'vault_cipher.dart';

/// Secret aléatoire conservé par le téléphone et nécessaire à la
/// récupération, en plus des trois réponses.
///
/// Il empêche de tester des réponses hors de l'application : le fichier du
/// coffre seul ne suffit pas, il faut ce téléphone et son code.
abstract class RecoverySecretStore {
  /// Crée et enregistre un nouveau secret ; peut demander le code du
  /// téléphone. Lève [DeviceUnlockCancelled] ou [DeviceUnlockFailure].
  Future<List<int>> create();

  /// Demande l'empreinte ou le code du téléphone, puis renvoie le secret.
  Future<List<int>> read();
}

/// Implémentation Android : secret chiffré par une clé AES du Keystore,
/// non exportable et utilisable uniquement après l'empreinte ou le code du
/// téléphone. Si le verrouillage d'écran est supprimé, le système détruit la
/// clé : la récupération devra être reconfigurée.
class KeystoreRecoverySecretStore implements RecoverySecretStore {
  static const _keyName = 'recovery_secret';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions.biometric(
      enforceBiometrics: true,
      requireBiometricsPerOperation: true,
      resetOnError: false,
      storageNamespace: 'maxsecurepass_recovery',
      biometricPromptTitle: 'Confirmer votre identité',
      biometricPromptSubtitle: 'Code ou empreinte du téléphone',
      biometricPromptNegativeButton: 'Annuler',
    ),
  );

  @override
  Future<List<int>> create() async {
    final secret = VaultCipher.randomBytes(32);
    await guardDeviceAuth(() => _storage.write(key: _keyName, value: base64Encode(secret)));
    return secret;
  }

  @override
  Future<List<int>> read() async {
    final value = await guardDeviceAuth(() => _storage.read(key: _keyName));
    if (value == null) {
      throw const DeviceUnlockFailure('Secret de récupération absent', permanent: true);
    }
    return base64Decode(value);
  }
}
