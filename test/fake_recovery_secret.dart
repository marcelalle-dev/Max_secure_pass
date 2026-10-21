import 'package:maxsecurepass/services/device_unlock.dart';
import 'package:maxsecurepass/services/recovery_secret.dart';
import 'package:maxsecurepass/services/vault_cipher.dart';

/// Simule le secret de récupération conservé par le Keystore.
class FakeRecoverySecretStore implements RecoverySecretStore {
  List<int>? secret;

  /// `true` : l'utilisateur confirme avec le code du téléphone ; `false` : il
  /// annule.
  bool confirm = true;

  /// Simule la suppression du verrouillage d'écran (clé détruite).
  bool invalidated = false;
  int prompts = 0;

  void _ask() {
    prompts++;
    if (invalidated) throw const DeviceUnlockFailure('invalidée', permanent: true);
    if (!confirm) throw const DeviceUnlockCancelled();
  }

  @override
  Future<List<int>> create() async {
    _ask();
    return secret = VaultCipher.randomBytes(32);
  }

  @override
  Future<List<int>> read() async {
    _ask();
    final value = secret;
    if (value == null) throw const DeviceUnlockFailure('absent', permanent: true);
    return value;
  }
}
