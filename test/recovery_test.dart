import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxsecurepass/models/vault_entry.dart';
import 'package:maxsecurepass/services/recovery_guard.dart';
import 'package:maxsecurepass/services/recovery_questions.dart';
import 'package:maxsecurepass/services/vault_cipher.dart';
import 'package:maxsecurepass/services/vault_service.dart';
import 'package:maxsecurepass/services/vault_storage.dart';

import 'fake_device_unlock.dart';
import 'fake_recovery_secret.dart';

const master = 'mot de passe maître';
const answers = ['Lycée Victor Hugo', 'Hélène', 'Aminata'];

void main() {
  late MemoryVaultStorage storage;
  late MemoryAttemptStore attempts;
  late FakeRecoverySecretStore secret;
  late FakeDeviceUnlock device;
  late DateTime now;
  late VaultService vault;

  int countAttempts() => attempts.data == null
      ? 0
      : (jsonDecode(attempts.data!) as Map<String, dynamic>)['attempts'] as int;

  /// Simule un redémarrage de l'application : nouveau service, mêmes données.
  Future<VaultService> restart() async {
    final service = VaultService(
      storage: storage,
      cipher: VaultCipher(iterations: 1000, recoveryIterations: 1000),
      deviceUnlock: device,
      recoverySecret: secret,
      attemptStore: attempts,
      clock: () => now,
    );
    await service.init();
    return service;
  }

  setUp(() async {
    storage = MemoryVaultStorage();
    attempts = MemoryAttemptStore();
    secret = FakeRecoverySecretStore();
    device = FakeDeviceUnlock();
    now = DateTime(2026, 10, 21, 12);
    vault = await restart();
    await vault.create(master);
    await vault.save(VaultEntry(title: 'Banque', username: 'alice', password: 'Tr3s-Secret!'));
    await vault.save(VaultEntry(title: 'Gmail', password: 'g-pass'));
    await vault.configureRecovery(answers);
    vault.lock();
  });

  group('configuration', () {
    test('un nouveau coffre doit configurer ses réponses', () async {
      final other = VaultService(
        storage: MemoryVaultStorage(),
        cipher: VaultCipher(iterations: 1000, recoveryIterations: 1000),
        recoverySecret: FakeRecoverySecretStore(),
      );
      await other.init();
      await other.create(master);
      expect(other.recoverySupported, isTrue);
      expect(other.recoveryConfigured, isFalse);
    });

    test('les réponses ne sont jamais enregistrées, ni en clair ni normalisées', () {
      final data = storage.data!;
      for (final answer in answers) {
        expect(data.toLowerCase(), isNot(contains(answer.toLowerCase())));
        expect(data, isNot(contains(normalizeAnswer(answer))));
        expect(data, isNot(contains(base64Encode(utf8.encode(normalizeAnswer(answer))))));
      }
      expect(attempts.data ?? '', isNot(contains('hugo')));
    });

    test('un sel aléatoire différent pour chaque réponse', () {
      final recovery =
          (jsonDecode(storage.data!) as Map<String, dynamic>)['recovery'] as Map<String, dynamic>;
      final salts = (recovery['salts'] as List).cast<String>();
      expect(salts, hasLength(3));
      expect(salts.toSet(), hasLength(3));
    });

    test('champs vides ou trop courts : configuration refusée', () async {
      final fresh = await restart();
      await fresh.unlock(master);
      for (final bad in [
        ['', 'Hélène', 'Aminata'],
        ['Lycée', '   ', 'Aminata'],
        ['Lycée', 'Hélène', 'a'],
        ['Lycée', 'Hélène'],
      ]) {
        expect(() => fresh.configureRecovery(bad), throwsArgumentError);
      }
    });

    test('normalisation : casse, espaces, accents et apostrophes', () {
      expect(normalizeAnswer('  Lycée   Victor HUGO '), 'lycee victor hugo');
      expect(normalizeAnswer('Saint-Exupéry'), normalizeAnswer('saint-exupery'));
      expect(normalizeAnswer('L’École'), "l'ecole");
    });

    test('la configuration survit au redémarrage', () async {
      final reopened = await restart();
      expect(reopened.recoveryConfigured, isTrue);
      final attempt = await reopened.verifyRecovery(answers);
      expect(attempt.outcome, RecoveryOutcome.allowed);
    });
  });

  group('vérification', () {
    test('trois réponses correctes : récupération autorisée', () async {
      final attempt = await vault.verifyRecovery(answers);
      expect(attempt.outcome, RecoveryOutcome.allowed);
      expect(attempt.session, isNotNull);
    });

    test('réponses saisies différemment mais équivalentes : autorisée', () async {
      final attempt = await vault.verifyRecovery([' lycee  victor hugo', 'HELENE', 'aminata ']);
      expect(attempt.outcome, RecoveryOutcome.allowed);
    });

    test('une réponse incorrecte : refusée', () async {
      for (var i = 0; i < 3; i++) {
        final wrong = List.of(answers)..[i] = 'Mauvaise réponse';
        final attempt = await vault.verifyRecovery(wrong);
        expect(attempt.outcome, RecoveryOutcome.refused, reason: 'réponse ${i + 1}');
        expect(attempt.session, isNull);
        await attempts.write(jsonEncode({'attempts': 0}));
      }
    });

    test('trois réponses incorrectes : refusée', () async {
      final attempt = await vault.verifyRecovery(['aaa', 'bbb', 'ccc']);
      expect(attempt.outcome, RecoveryOutcome.refused);
    });

    test('réponses dans le désordre : refusée', () async {
      final attempt = await vault.verifyRecovery([answers[1], answers[0], answers[2]]);
      expect(attempt.outcome, RecoveryOutcome.refused);
    });

    test('champs vides : vérification bloquée, aucune tentative comptée', () async {
      expect(() => vault.verifyRecovery(['', '', '']), throwsArgumentError);
      expect(countAttempts(), 0);
    });

    test('impossible quand le coffre est déjà ouvert', () async {
      await vault.unlock(master);
      expect(() => vault.verifyRecovery(answers), throwsStateError);
    });

    test('confirmation par le téléphone annulée : rien n\'est compté', () async {
      secret.confirm = false;
      final attempt = await vault.verifyRecovery(answers);
      expect(attempt.outcome, RecoveryOutcome.cancelled);
      expect(await vault.recoveryWait(), Duration.zero);
      expect(countAttempts(), 0);
    });

    test('verrouillage d\'écran supprimé : indisponible, puis reconfiguration demandée', () async {
      secret.invalidated = true;
      final attempt = await vault.verifyRecovery(answers);
      expect(attempt.outcome, RecoveryOutcome.unavailable);
      expect(vault.recoveryConfigured, isFalse);

      // Les données sont intactes ; la configuration sera redemandée.
      final reopened = await restart();
      expect(reopened.recoveryConfigured, isFalse);
      expect(await reopened.unlock(master), isTrue);
      expect(reopened.entries, hasLength(2));
      secret.invalidated = false;
      await reopened.configureRecovery(answers);
      reopened.lock();
      expect((await reopened.verifyRecovery(answers)).outcome, RecoveryOutcome.allowed);
    });

    test('sans le secret du téléphone, les bonnes réponses ne suffisent pas', () async {
      secret.secret = VaultCipher.randomBytes(32);
      final attempt = await vault.verifyRecovery(answers);
      expect(attempt.outcome, RecoveryOutcome.refused);
    });
  });

  group('limitation des tentatives', () {
    test('délai progressif après les essais libres, même avec les bonnes réponses', () async {
      for (var i = 0; i < RecoveryGuard.freeAttempts; i++) {
        final attempt = await vault.verifyRecovery(['aaa', 'bbb', 'ccc']);
        expect(attempt.outcome, RecoveryOutcome.refused);
      }
      expect(await vault.recoveryWait(), const Duration(seconds: 30));

      final blocked = await vault.verifyRecovery(answers);
      expect(blocked.outcome, RecoveryOutcome.throttled);
      expect(blocked.session, isNull);

      now = now.add(const Duration(seconds: 31));
      expect((await vault.verifyRecovery(['aaa', 'bbb', 'ccc'])).outcome, RecoveryOutcome.refused);
      expect(await vault.recoveryWait(), const Duration(minutes: 1));

      now = now.add(const Duration(minutes: 1, seconds: 1));
      expect((await vault.verifyRecovery(['aaa', 'bbb', 'ccc'])).outcome, RecoveryOutcome.refused);
      expect(await vault.recoveryWait(), const Duration(minutes: 5));
    });

    test('le délai survit au redémarrage de l\'application', () async {
      for (var i = 0; i < RecoveryGuard.freeAttempts; i++) {
        await vault.verifyRecovery(['aaa', 'bbb', 'ccc']);
      }
      final reopened = await restart();
      expect((await reopened.verifyRecovery(answers)).outcome, RecoveryOutcome.throttled);
    });

    test('reculer l\'horloge ne raccourcit pas l\'attente', () async {
      for (var i = 0; i < RecoveryGuard.freeAttempts; i++) {
        await vault.verifyRecovery(['aaa', 'bbb', 'ccc']);
      }
      now = now.subtract(const Duration(days: 1));
      expect((await vault.verifyRecovery(answers)).outcome, RecoveryOutcome.throttled);
    });

    test('compteur illisible : délai maximal appliqué', () async {
      await attempts.write('corrompu');
      expect(await vault.recoveryWait(), RecoveryGuard.delays.last);
    });

    test('une récupération réussie remet le compteur à zéro', () async {
      await vault.verifyRecovery(['aaa', 'bbb', 'ccc']);
      await vault.verifyRecovery(['aaa', 'bbb', 'ccc']);
      final attempt = await vault.verifyRecovery(answers);
      expect(attempt.outcome, RecoveryOutcome.allowed);
      expect(await vault.recoveryWait(), Duration.zero);
    });
  });

  group('réinitialisation', () {
    Future<void> recoverWith(String newPassword) async {
      final attempt = await vault.verifyRecovery(answers);
      await vault.completeRecovery(attempt.session!, newPassword);
    }

    test('le nouveau mot de passe ouvre le coffre, l\'ancien non', () async {
      await recoverWith('nouveau mot de passe');
      expect(vault.status, VaultStatus.unlocked);

      final reopened = await restart();
      expect(await reopened.unlock(master), isFalse);
      expect(await reopened.unlock('nouveau mot de passe'), isTrue);
    });

    test('les anciennes données restent accessibles', () async {
      await recoverWith('nouveau mot de passe');
      expect(vault.entries.map((e) => e.title), ['Banque', 'Gmail']);
      expect(vault.entries.first.password, 'Tr3s-Secret!');

      final reopened = await restart();
      await reopened.unlock('nouveau mot de passe');
      expect(reopened.entries.first.username, 'alice');
    });

    test('les questions restent valables après la réinitialisation', () async {
      await recoverWith('nouveau mot de passe');
      vault.lock();
      expect((await vault.verifyRecovery(answers)).outcome, RecoveryOutcome.allowed);
    });

    test('le déverrouillage par empreinte reste valable', () async {
      await vault.unlock(master);
      await vault.enableDeviceUnlock();
      vault.lock();
      await recoverWith('nouveau mot de passe');
      vault.lock();
      expect(await vault.unlockWithDevice(), DeviceUnlockOutcome.unlocked);
    });

    test('le nouveau mot de passe suit les règles existantes', () async {
      final attempt = await vault.verifyRecovery(answers);
      expect(() => vault.completeRecovery(attempt.session!, 'court'), throwsArgumentError);
      // La session n'est pas consommée par un mot de passe refusé.
      await vault.completeRecovery(attempt.session!, 'nouveau mot de passe');
      expect(vault.status, VaultStatus.unlocked);
    });

    test('rejeu : une autorisation ne sert qu\'une fois', () async {
      final attempt = await vault.verifyRecovery(answers);
      await vault.completeRecovery(attempt.session!, 'nouveau mot de passe');
      vault.lock();
      expect(() => vault.completeRecovery(attempt.session!, 'encore un autre'), throwsStateError);
    });

    test('rejeu : l\'autorisation expire', () async {
      final attempt = await vault.verifyRecovery(answers);
      now = now.add(RecoverySession.lifetime + const Duration(seconds: 1));
      expect(
        () => vault.completeRecovery(attempt.session!, 'nouveau mot de passe'),
        throwsStateError,
      );
    });

    test('rejeu : le verrouillage annule l\'autorisation', () async {
      final attempt = await vault.verifyRecovery(answers);
      vault.lock();
      expect(
        () => vault.completeRecovery(attempt.session!, 'nouveau mot de passe'),
        throwsStateError,
      );
    });

    test('rejeu : une autorisation d\'un autre lancement est refusée', () async {
      final attempt = await vault.verifyRecovery(answers);
      final reopened = await restart();
      expect(
        () => reopened.completeRecovery(attempt.session!, 'nouveau mot de passe'),
        throwsStateError,
      );
    });
  });

  group('intégrité', () {
    test('un verrou de récupération modifié est refusé', () async {
      final json = jsonDecode(storage.data!) as Map<String, dynamic>;
      final wrapped =
          (json['recovery'] as Map<String, dynamic>)['wrappedKey'] as Map<String, dynamic>;
      final bytes = base64Decode(wrapped['ciphertext'] as String)..[0] ^= 1;
      wrapped['ciphertext'] = base64Encode(bytes);
      storage.data = jsonEncode(json);
      final reopened = await restart();
      expect((await reopened.verifyRecovery(answers)).outcome, RecoveryOutcome.refused);
    });

    test('un verrou copié depuis un autre coffre est refusé', () async {
      // Autre coffre dont l'attaquant connaît les réponses.
      final otherStorage = MemoryVaultStorage();
      final other = VaultService(
        storage: otherStorage,
        cipher: VaultCipher(iterations: 1000, recoveryIterations: 1000),
        recoverySecret: secret,
      );
      await other.init();
      await other.create('autre mot de passe');
      await other.configureRecovery(['aaa', 'bbb', 'ccc']);

      final json = jsonDecode(storage.data!) as Map<String, dynamic>;
      json['recovery'] = (jsonDecode(otherStorage.data!) as Map<String, dynamic>)['recovery'];
      storage.data = jsonEncode(json);
      final reopened = await restart();
      expect(
        (await reopened.verifyRecovery(['aaa', 'bbb', 'ccc'])).outcome,
        RecoveryOutcome.refused,
      );
    });
  });

  group('migration de l\'ancien format', () {
    test('un coffre v1 est converti sans perte, puis la configuration est demandée', () async {
      // Coffre v1 : données chiffrées directement par la clé du mot de passe.
      final legacyStorage = MemoryVaultStorage(
        await _legacyVault(master, [VaultEntry(title: 'Ancien', password: 'v1-secret')]),
      );
      final migrated = VaultService(
        storage: legacyStorage,
        cipher: VaultCipher(iterations: 1000, recoveryIterations: 1000),
        recoverySecret: FakeRecoverySecretStore(),
      );
      await migrated.init();
      expect(migrated.status, VaultStatus.locked);
      expect(migrated.recoveryConfigured, isFalse);

      expect(await migrated.unlock('mauvais'), isFalse);
      expect(jsonDecode(legacyStorage.data!)['version'], 1);

      expect(await migrated.unlock(master), isTrue);
      expect(migrated.entries.single.password, 'v1-secret');
      expect(jsonDecode(legacyStorage.data!)['version'], 2);
      expect(migrated.recoveryConfigured, isFalse);

      await migrated.configureRecovery(answers);
      migrated.lock();
      final attempt = await migrated.verifyRecovery(answers);
      await migrated.completeRecovery(attempt.session!, 'nouveau mot de passe');
      expect(migrated.entries.single.password, 'v1-secret');
    });
  });
}

/// Fabrique un coffre au format 1, tel qu'enregistré par les versions
/// précédentes de l'application.
Future<String> _legacyVault(String password, List<VaultEntry> entries) async {
  final cipher = VaultCipher(iterations: 1000);
  final salt = VaultCipher.randomBytes(16);
  final key = await cipher.deriveMasterKey(password, salt, 1000);
  final sealed = await cipher.seal(
    utf8.encode(jsonEncode(entries.map((e) => e.toJson()).toList())),
    key,
    '',
  );
  return jsonEncode({
    'version': 1,
    'kdf': 'pbkdf2-hmac-sha256',
    'iterations': 1000,
    'salt': base64Encode(salt),
    'nonce': base64Encode(sealed.nonce),
    'ciphertext': base64Encode(sealed.cipherText),
    'mac': base64Encode(sealed.mac),
  });
}
