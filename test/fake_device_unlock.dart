import 'package:maxsecurepass/services/device_unlock.dart';

/// Simule l'empreinte ou le code du téléphone.
class FakeDeviceUnlock implements DeviceUnlock {
  FakeDeviceUnlock({this.available = true});

  bool available;
  List<int>? storedKey;

  /// Prochaine réponse de l'utilisateur : `true` accepte, `false` annule,
  /// `null` simule une erreur passagère du téléphone (trop d'essais…).
  bool? nextAnswer = true;

  /// Simule une clé invalidée par le système.
  bool keyInvalidated = false;
  int prompts = 0;

  Future<void> _ask() async {
    prompts++;
    final answer = nextAnswer;
    if (keyInvalidated) throw const DeviceUnlockFailure('invalidée', permanent: true);
    if (answer == null) throw const DeviceUnlockFailure('erreur simulée');
    if (!answer) throw const DeviceUnlockCancelled();
  }

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> isEnabled() async => storedKey != null;

  @override
  Future<void> enable(List<int> key) async {
    await _ask();
    storedKey = List.of(key);
  }

  @override
  Future<List<int>> readKey() async {
    await _ask();
    final key = storedKey;
    if (key == null) throw const DeviceUnlockFailure('aucune clé');
    return key;
  }

  @override
  Future<void> disable() async => storedKey = null;
}
