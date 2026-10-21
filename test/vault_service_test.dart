import 'package:flutter_test/flutter_test.dart';
import 'package:maxsecurepass/models/vault_entry.dart';
import 'package:maxsecurepass/services/vault_cipher.dart';
import 'package:maxsecurepass/services/vault_service.dart';
import 'package:maxsecurepass/services/vault_storage.dart';

void main() {
  late MemoryVaultStorage storage;
  late VaultService vault;

  VaultService newService() =>
      VaultService(storage: storage, cipher: VaultCipher(iterations: 1000));

  setUp(() async {
    storage = MemoryVaultStorage();
    vault = newService();
    await vault.init();
  });

  test('un nouveau coffre est non initialisé', () {
    expect(vault.status, VaultStatus.uninitialized);
  });

  test('refuse un mot de passe maître trop court', () {
    expect(() => vault.create('court'), throwsArgumentError);
  });

  test('les données sont chiffrées et relisibles avec le bon mot de passe', () async {
    await vault.create('mot de passe maître');
    await vault.save(VaultEntry(title: 'Banque', username: 'alice', password: 'Tr3s-Secret!'));
    expect(storage.data, isNot(contains('Tr3s-Secret!')));
    expect(storage.data, isNot(contains('Banque')));

    final reopened = newService();
    await reopened.init();
    expect(reopened.status, VaultStatus.locked);
    expect(await reopened.unlock('mauvais mot de passe'), isFalse);
    expect(reopened.status, VaultStatus.locked);
    expect(await reopened.unlock('mot de passe maître'), isTrue);
    expect(reopened.entries.single.password, 'Tr3s-Secret!');
  });

  test('modification, suppression et tri', () async {
    await vault.create('mot de passe maître');
    final b = VaultEntry(title: 'b');
    await vault.save(b);
    await vault.save(VaultEntry(title: 'A'));
    expect(vault.entries.map((e) => e.title), ['A', 'b']);

    await vault.save(b.copyWith(title: 'C'));
    expect(vault.entries.map((e) => e.title), ['A', 'C']);

    await vault.delete(b.id);
    expect(vault.entries.map((e) => e.title), ['A']);
  });

  test('le verrouillage efface les données en mémoire', () async {
    await vault.create('mot de passe maître');
    await vault.save(VaultEntry(title: 'A'));
    vault.lock();
    expect(vault.status, VaultStatus.locked);
    expect(vault.entries, isEmpty);
    expect(() => vault.save(VaultEntry(title: 'B')), throwsStateError);
  });

  test('changement du mot de passe maître', () async {
    await vault.create('ancien mot de passe');
    await vault.save(VaultEntry(title: 'A'));
    expect(await vault.changeMasterPassword('faux', 'nouveau mot de passe'), isFalse);
    expect(await vault.changeMasterPassword('ancien mot de passe', 'nouveau mot de passe'), isTrue);

    final reopened = newService();
    await reopened.init();
    expect(await reopened.unlock('ancien mot de passe'), isFalse);
    expect(await reopened.unlock('nouveau mot de passe'), isTrue);
    expect(reopened.entries.single.title, 'A');
  });

  test('un coffre altéré est rejeté', () async {
    await vault.create('mot de passe maître');
    storage.data = storage.data!.replaceFirst('"ciphertext":"', '"ciphertext":"AAAA');
    final reopened = newService();
    await reopened.init();
    expect(await reopened.unlock('mot de passe maître'), isFalse);
  });
}
