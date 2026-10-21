import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';

/// L'utilisateur a fermé la demande d'empreinte ou de code.
class DeviceUnlockCancelled implements Exception {
  const DeviceUnlockCancelled();
}

/// Le téléphone n'a pas rendu la clé.
class DeviceUnlockFailure implements Exception {
  const DeviceUnlockFailure(this.message, {this.permanent = false});

  final String message;

  /// La clé est perdue (invalidée par le système, effacée…) : réessayer ne
  /// servira à rien. Sinon l'échec est passager (trop d'essais, capteur
  /// indisponible).
  final bool permanent;

  @override
  String toString() => 'DeviceUnlockFailure: $message';
}

/// Conserve la clé du coffre sous la protection de l'empreinte ou du code
/// du téléphone.
abstract class DeviceUnlock {
  Future<bool> isAvailable();

  Future<bool> isEnabled();

  /// Enregistre [key] ; peut demander l'empreinte ou le code.
  Future<void> enable(List<int> key);

  /// Demande l'empreinte ou le code, puis renvoie la clé.
  Future<List<int>> readKey();

  Future<void> disable();
}

/// Implémentation Android : la clé est chiffrée par une clé AES du Keystore
/// créée avec `setUserAuthenticationRequired(true)`. Le système ne la rend
/// utilisable qu'après l'empreinte ou le code, à chaque lecture.
class KeystoreDeviceUnlock implements DeviceUnlock {
  static const _keyName = 'vault_key';
  static const _markerName = 'device_unlock_enabled';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions.biometric(
      enforceBiometrics: true,
      requireBiometricsPerOperation: true,
      // Une annulation ne doit pas effacer la clé enregistrée.
      resetOnError: false,
      storageNamespace: 'maxsecurepass_device_unlock',
      biometricPromptTitle: 'Déverrouiller Max SecurePass',
      biometricPromptSubtitle: 'Empreinte ou code du téléphone',
      biometricPromptNegativeButton: 'Annuler',
    ),
  );

  // Codes de BiometricPrompt : https://developer.android.com/reference/androidx/biometric/BiometricPrompt
  static const _cancelCodes = {3, 5, 10, 13}; // délai, annulé, utilisateur, bouton Annuler

  Future<File> _marker() async =>
      File('${(await getApplicationSupportDirectory()).path}/$_markerName');

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      return await LocalAuthentication().isDeviceSupported();
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> isEnabled() async => (await _marker()).exists();

  @override
  Future<void> enable(List<int> key) async {
    await _guard(() => _storage.write(key: _keyName, value: base64Encode(key)));
    await (await _marker()).writeAsString('1', flush: true);
  }

  @override
  Future<List<int>> readKey() async {
    final value = await _guard(() => _storage.read(key: _keyName));
    if (value == null) {
      throw const DeviceUnlockFailure('Aucune clé enregistrée', permanent: true);
    }
    return base64Decode(value);
  }

  @override
  Future<void> disable() async {
    final marker = await _marker();
    if (await marker.exists()) await marker.delete();
    try {
      await _storage.delete(key: _keyName);
    } on Exception {
      // Sans le marqueur, la clé ne sera plus utilisée.
    }
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException catch (e) {
      final text = '${e.message} ${e.details}';
      final code = RegExp(r'Biometric authentication error \[(\d+)\]').firstMatch(text);
      if (code != null && _cancelCodes.contains(int.parse(code[1]!))) {
        throw const DeviceUnlockCancelled();
      }
      throw DeviceUnlockFailure(
        text,
        permanent: text.contains('KeyPermanentlyInvalidated') || text.contains('UnrecoverableKey'),
      );
    }
  }
}
