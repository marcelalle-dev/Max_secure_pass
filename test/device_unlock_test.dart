import 'package:flutter_test/flutter_test.dart';
import 'package:maxsecurepass/models/vault_entry.dart';
import 'package:maxsecurepass/services/device_unlock.dart';
import 'package:maxsecurepass/services/vault_cipher.dart';
import 'package:maxsecurepass/services/vault_service.dart';
import 'package:maxsecurepass/services/vault_storage.dart';

import 'fake_device_unlock.dart';

void main() {
  late MemoryVaultStorage storage;
  late FakeDeviceUnlock device;
  late VaultService vault;

  VaultService newService() =>
      VaultService(storage: storage, cipher: VaultCipher(iterations: 1000), deviceUnlock: device);

  setUp(() async {
    storage = MemoryVaultStorage();
    device = FakeDeviceUnlock();
    vault = newService();
    await vault.init();
    await vault.create('mot de passe maître');
    await vault.save(VaultEntry(title: 'Banque', password: 'secret'));
  });

  test('propose une seule fois l\'activation après la création', () {
    expect(vault.takeDeviceUnlockOffer(), isTrue);
    expect(vault.takeDeviceUnlockOffer(), isFalse);
  });

  test('pas de proposition si le téléphone n\'a ni empreinte ni code', () async {
    device.available = false;
    final other = VaultService(
      storage: MemoryVaultStorage(),
      deviceUnlock: device,
      cipher: VaultCipher(iterations: 1000),
    );
    await other.init();
    await other.create('mot de passe maître');
    expect(other.takeDeviceUnlockOffer(), isFalse);
  });

  test('déverrouille avec le téléphone après activation, même après redémarrage', () async {
    await vault.enableDeviceUnlock();
    expect(vault.deviceUnlockEnabled, isTrue);

    final reopened = newService();
    await reopened.init();
    expect(reopened.deviceUnlockEnabled, isTrue);
    expect(await reopened.unlockWithDevice(), DeviceUnlockOutcome.unlocked);
    expect(reopened.entries.single.password, 'secret');
  });

  test('annuler la demande laisse le coffre verrouillé et l\'option active', () async {
    await vault.enableDeviceUnlock();
    vault.lock();
    device.nextAnswer = false;
    expect(await vault.unlockWithDevice(), DeviceUnlockOutcome.cancelled);
    expect(vault.status, VaultStatus.locked);
    expect(vault.deviceUnlockEnabled, isTrue);
  });

  test('une erreur passagère garde l\'option active', () async {
    await vault.enableDeviceUnlock();
    vault.lock();
    device.nextAnswer = null;
    expect(await vault.unlockWithDevice(), DeviceUnlockOutcome.failed);
    expect(vault.status, VaultStatus.locked);
    expect(vault.deviceUnlockEnabled, isTrue);
    expect(await vault.unlock('mot de passe maître'), isTrue);
  });

  test('une clé invalidée par le système désactive l\'option', () async {
    await vault.enableDeviceUnlock();
    vault.lock();
    device.keyInvalidated = true;
    expect(await vault.unlockWithDevice(), DeviceUnlockOutcome.disabled);
    expect(vault.deviceUnlockEnabled, isFalse);
  });

  test('une clé périmée est refusée et l\'option désactivée', () async {
    await vault.enableDeviceUnlock();
    device.storedKey = List.filled(32, 7);
    vault.lock();
    expect(await vault.unlockWithDevice(), DeviceUnlockOutcome.disabled);
    expect(vault.status, VaultStatus.locked);
    expect(device.storedKey, isNull);
  });

  test('l\'activation annulée ne change rien', () async {
    device.nextAnswer = false;
    await expectLater(vault.enableDeviceUnlock(), throwsA(isA<DeviceUnlockCancelled>()));
    expect(vault.deviceUnlockEnabled, isFalse);
  });

  test('changer le mot de passe maître met à jour la clé du téléphone', () async {
    await vault.enableDeviceUnlock();
    await vault.changeMasterPassword('mot de passe maître', 'nouveau mot de passe');
    vault.lock();
    expect(await vault.unlockWithDevice(), DeviceUnlockOutcome.unlocked);
  });

  test('si la mise à jour échoue, l\'option est désactivée', () async {
    await vault.enableDeviceUnlock();
    device.nextAnswer = false;
    await vault.changeMasterPassword('mot de passe maître', 'nouveau mot de passe');
    expect(vault.deviceUnlockEnabled, isFalse);
  });

  test('le verrouillage volontaire est mémorisé', () async {
    vault.lock(byUser: true);
    expect(vault.lockedByUser, isTrue);
    await vault.unlock('mot de passe maître');
    vault.lock();
    expect(vault.lockedByUser, isFalse);
  });
}
