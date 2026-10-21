import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../models/vault_entry.dart';
import 'device_unlock.dart';
import 'recovery_guard.dart';
import 'recovery_questions.dart';
import 'recovery_secret.dart';
import 'vault_cipher.dart';
import 'vault_file.dart';
import 'vault_storage.dart';

enum VaultStatus { loading, uninitialized, locked, unlocked }

enum DeviceUnlockOutcome {
  unlocked,
  cancelled,

  /// Échec passager (trop d'essais, capteur indisponible) : l'option reste
  /// active, le mot de passe maître reste utilisable.
  failed,

  /// La clé enregistrée ne correspond plus au coffre ou le téléphone ne
  /// peut plus la rendre : le déverrouillage par le téléphone est désactivé.
  disabled,

  /// Coffre à l'ancien format : il doit être ouvert une fois avec le mot de
  /// passe maître pour être mis à jour.
  masterPasswordRequired,
}

enum RecoveryOutcome {
  /// Les trois réponses sont correctes : [RecoveryAttempt.session] permet
  /// de choisir un nouveau mot de passe maître.
  allowed,

  /// Au moins une réponse est incorrecte (sans dire laquelle).
  refused,

  /// Trop de tentatives : attendre [RecoveryAttempt.wait].
  throttled,

  /// La confirmation par le téléphone a été annulée ; rien n'a été vérifié.
  cancelled,

  /// Le téléphone ne peut plus fournir son secret (verrouillage d'écran
  /// supprimé ou modifié) : la récupération est impossible sur ce coffre.
  unavailable,
}

class RecoveryAttempt {
  const RecoveryAttempt(this.outcome, {this.wait = Duration.zero, this.session});

  final RecoveryOutcome outcome;

  /// Délai avant la prochaine tentative.
  final Duration wait;
  final RecoverySession? session;
}

/// Autorisation de réinitialiser le mot de passe maître, obtenue après des
/// réponses correctes. Elle ne sert qu'une fois, expire au bout de
/// [RecoverySession.lifetime] et est annulée au verrouillage : elle ne peut
/// pas être rejouée.
class RecoverySession {
  RecoverySession._(this._dataKey, this._revision, this.expiresAt);

  static const lifetime = Duration(minutes: 5);

  final SecretKey _dataKey;
  final int _revision;
  final DateTime expiresAt;
  bool _used = false;
}

/// État du coffre : création, déverrouillage, verrouillage, modifications et
/// récupération. Les entrées déchiffrées et la clé de coffre ne restent en
/// mémoire que tant que le coffre est déverrouillé.
class VaultService extends ChangeNotifier {
  VaultService({
    required this.storage,
    VaultCipher? cipher,
    this.deviceUnlock,
    this.recoverySecret,
    AttemptStore? attemptStore,
    DateTime Function()? clock,
  }) : cipher = cipher ?? VaultCipher(),
       _clock = clock ?? DateTime.now,
       _guard = RecoveryGuard(attemptStore ?? MemoryAttemptStore(), clock: clock);

  static const minMasterPasswordLength = 8;

  final VaultStorage storage;
  final VaultCipher cipher;

  /// `null` si la plateforme ne permet pas le déverrouillage par le téléphone.
  final DeviceUnlock? deviceUnlock;

  /// `null` si la plateforme ne permet pas la récupération par questions.
  final RecoverySecretStore? recoverySecret;

  final DateTime Function() _clock;
  final RecoveryGuard _guard;

  VaultStatus _status = VaultStatus.loading;

  /// En-tête du coffre (format 2) ; `null` pour un coffre à l'ancien format.
  VaultFile? _file;
  SecretKey? _dataKey;
  List<VaultEntry> _entries = [];
  RecoverySession? _session;
  bool _deviceUnlockAvailable = false;
  bool _deviceUnlockEnabled = false;
  bool _deviceAuthInProgress = false;
  bool _lockedByUser = false;
  bool _offerDeviceUnlock = false;

  VaultStatus get status => _status;

  /// Le téléphone a une empreinte ou un code configuré.
  bool get deviceUnlockAvailable => _deviceUnlockAvailable;

  bool get deviceUnlockEnabled => _deviceUnlockEnabled;

  /// Une demande d'empreinte ou de code est affichée. Sur Android, la saisie
  /// du code ouvre un écran système qui met l'application en arrière-plan :
  /// le verrouillage automatique doit alors être ignoré.
  bool get deviceAuthInProgress => _deviceAuthInProgress;

  /// Le dernier verrouillage vient du bouton « Verrouiller » : on ne
  /// redemande pas aussitôt l'empreinte.
  bool get lockedByUser => _lockedByUser;

  /// La plateforme permet la récupération par questions.
  bool get recoverySupported => recoverySecret != null;

  /// Les trois réponses de récupération sont configurées.
  bool get recoveryConfigured =>
      _file?.recovery?.questionsVersion == recoveryQuestionsVersion && recoverySecret != null;

  /// Entrées triées par titre.
  List<VaultEntry> get entries => List.unmodifiable(_entries);

  Future<void> init() async {
    final data = await storage.read();
    if (data != null && VaultFile.versionOf(data) == VaultFile.version) {
      _file = VaultFile.decode(data);
    }
    final device = deviceUnlock;
    if (device != null) {
      _deviceUnlockAvailable = await device.isAvailable();
      _deviceUnlockEnabled = data != null && await device.isEnabled();
    }
    _setStatus(data == null ? VaultStatus.uninitialized : VaultStatus.locked);
  }

  /// Vrai une seule fois, juste après la création du coffre (ou sa mise à
  /// jour), si le téléphone permet d'activer le déverrouillage par empreinte.
  bool takeDeviceUnlockOffer() {
    final offer = _offerDeviceUnlock && _deviceUnlockAvailable && !_deviceUnlockEnabled;
    _offerDeviceUnlock = false;
    return offer;
  }

  Future<void> create(String masterPassword) async {
    _checkMasterPassword(masterPassword);
    final dataKey = cipher.newDataKey();
    final vaultId = base64UrlEncode(VaultCipher.randomBytes(16));
    final master = await _masterLock(masterPassword, dataKey, vaultId);
    _file = VaultFile(
      vaultId: vaultId,
      revision: 0,
      master: master,
      recovery: null,
      payload: const Sealed([], [], []),
    );
    _dataKey = dataKey;
    _entries = [];
    await _save();
    _offerDeviceUnlock = true;
    _setStatus(VaultStatus.unlocked);
  }

  /// Renvoie `false` si le mot de passe est incorrect.
  Future<bool> unlock(String masterPassword) async {
    final data = await storage.read();
    if (data == null) return false;
    try {
      if (VaultFile.versionOf(data) != VaultFile.version) {
        await _migrateLegacy(data, masterPassword);
        return true;
      }
      final file = VaultFile.decode(data);
      final kek = await cipher.deriveMasterKey(
        masterPassword,
        file.master.salt,
        file.master.iterations,
      );
      final dataKey = SecretKey(await cipher.open(file.master.wrappedKey, kek, file.masterContext));
      await _open(file, dataKey);
      return true;
    } on WrongPasswordException {
      return false;
    }
  }

  /// Format 1 → 2 : nouvelle clé de coffre aléatoire, données rechiffrées.
  /// Les questions de récupération seront demandées juste après.
  Future<void> _migrateLegacy(String data, String masterPassword) async {
    final clear = await cipher.decryptLegacy(
      jsonDecode(data) as Map<String, dynamic>,
      masterPassword,
    );
    final dataKey = cipher.newDataKey();
    final vaultId = base64UrlEncode(VaultCipher.randomBytes(16));
    _file = VaultFile(
      vaultId: vaultId,
      revision: 0,
      master: await _masterLock(masterPassword, dataKey, vaultId),
      recovery: null,
      payload: const Sealed([], [], []),
    );
    _dataKey = dataKey;
    _entries = _decodeEntries(clear);
    await _save();
    if (_deviceUnlockEnabled) {
      // La clé enregistrée par le téléphone était celle de l'ancien format.
      await disableDeviceUnlock();
      _offerDeviceUnlock = true;
    }
    _lockedByUser = false;
    _setStatus(VaultStatus.unlocked);
  }

  /// Déverrouille avec l'empreinte ou le code du téléphone.
  Future<DeviceUnlockOutcome> unlockWithDevice() async {
    final device = deviceUnlock;
    final data = await storage.read();
    if (device == null || !_deviceUnlockEnabled || data == null) {
      return DeviceUnlockOutcome.disabled;
    }
    if (VaultFile.versionOf(data) != VaultFile.version) {
      return DeviceUnlockOutcome.masterPasswordRequired;
    }
    try {
      final keyBytes = await _withDeviceAuth(device.readKey);
      await _open(VaultFile.decode(data), SecretKey(keyBytes));
      return DeviceUnlockOutcome.unlocked;
    } on DeviceUnlockCancelled {
      return DeviceUnlockOutcome.cancelled;
    } on DeviceUnlockFailure catch (e) {
      if (!e.permanent) return DeviceUnlockOutcome.failed;
      await disableDeviceUnlock();
      return DeviceUnlockOutcome.disabled;
    } on Exception {
      // Clé périmée ou illisible : on revient au mot de passe maître.
      await disableDeviceUnlock();
      return DeviceUnlockOutcome.disabled;
    }
  }

  /// Active le déverrouillage par le téléphone. Lève [DeviceUnlockCancelled]
  /// ou [DeviceUnlockFailure].
  Future<void> enableDeviceUnlock() async {
    _requireUnlocked();
    final device = deviceUnlock;
    if (device == null) throw const DeviceUnlockFailure('Non disponible');
    final keyBytes = await _dataKey!.extractBytes();
    await _withDeviceAuth(() => device.enable(keyBytes));
    _deviceUnlockEnabled = true;
    notifyListeners();
  }

  Future<void> disableDeviceUnlock() async {
    await deviceUnlock?.disable();
    _deviceUnlockEnabled = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Récupération par questions

  /// Enregistre les trois réponses : la clé de coffre est verrouillée une
  /// seconde fois par une clé dérivée des réponses et du secret du
  /// téléphone. Les réponses ne sont enregistrées nulle part.
  ///
  /// Lève [ArgumentError] si une réponse est vide, [DeviceUnlockCancelled]
  /// ou [DeviceUnlockFailure] si le téléphone n'a pas pu créer son secret.
  Future<void> configureRecovery(List<String> answers) async {
    _requireUnlocked();
    final normalized = _checkAnswers(answers);
    final secretStore = recoverySecret;
    if (secretStore == null) throw const DeviceUnlockFailure('Non disponible');
    final file = _file!;
    final deviceSecret = await _withDeviceAuth(secretStore.create);
    final salts = [for (var i = 0; i < normalized.length; i++) VaultCipher.randomBytes(16)];
    final kek = await cipher.deriveRecoveryKey(
      normalized,
      salts,
      cipher.recoveryIterations,
      deviceSecret,
    );
    final wrapped = await cipher.seal(await _dataKey!.extractBytes(), kek, file.recoveryContext);
    _file = file.copyWith(
      recovery: RecoveryLock(
        questionsVersion: recoveryQuestionsVersion,
        salts: salts,
        iterations: cipher.recoveryIterations,
        wrappedKey: wrapped,
      ),
    );
    await _save();
    await _guard.reset();
    notifyListeners();
  }

  /// Délai avant la prochaine tentative de récupération.
  Future<Duration> recoveryWait() => _guard.remaining();

  /// Vérifie les trois réponses. Ne dit jamais laquelle est fausse.
  ///
  /// Lève [ArgumentError] si une réponse est vide (aucune tentative n'est
  /// alors comptée).
  Future<RecoveryAttempt> verifyRecovery(List<String> answers) async {
    if (_status != VaultStatus.locked || !recoveryConfigured) {
      throw StateError('Récupération non disponible.');
    }
    final normalized = _checkAnswers(answers);
    final wait = await _guard.remaining();
    if (wait > Duration.zero) return RecoveryAttempt(RecoveryOutcome.throttled, wait: wait);

    final List<int> deviceSecret;
    try {
      deviceSecret = await _withDeviceAuth(recoverySecret!.read);
    } on DeviceUnlockCancelled {
      return const RecoveryAttempt(RecoveryOutcome.cancelled);
    } on DeviceUnlockFailure catch (e) {
      if (!e.permanent) return const RecoveryAttempt(RecoveryOutcome.cancelled);
      // Le téléphone a détruit son secret (verrouillage d'écran supprimé ou
      // modifié) : ce verrou ne pourra plus jamais s'ouvrir. On le retire pour
      // que la configuration soit redemandée à la prochaine ouverture.
      _file = _file!.withoutRecovery();
      await storage.write(_file!.encode());
      return const RecoveryAttempt(RecoveryOutcome.unavailable);
    }

    // Comptée avant la vérification : interrompre l'application ne l'annule pas.
    await _guard.recordAttempt();
    final file = _file!;
    final lock = file.recovery!;
    final kek = await cipher.deriveRecoveryKey(
      normalized,
      lock.salts,
      lock.iterations,
      deviceSecret,
    );
    try {
      final dataKey = SecretKey(await cipher.open(lock.wrappedKey, kek, file.recoveryContext));
      await _guard.reset();
      final session = RecoverySession._(
        dataKey,
        file.revision,
        _clock().add(RecoverySession.lifetime),
      );
      _session = session;
      return RecoveryAttempt(RecoveryOutcome.allowed, session: session);
    } on WrongPasswordException {
      return RecoveryAttempt(RecoveryOutcome.refused, wait: await _guard.remaining());
    }
  }

  /// Remplace le mot de passe maître grâce à une [session] obtenue par
  /// [verifyRecovery], puis ouvre le coffre. Toutes les données sont
  /// conservées : seule la clé de coffre est reverrouillée.
  ///
  /// Lève [StateError] si la session est expirée, déjà utilisée ou
  /// annulée par un verrouillage.
  Future<void> completeRecovery(RecoverySession session, String newPassword) async {
    _checkMasterPassword(newPassword);
    final file = _file;
    if (!identical(session, _session) ||
        session._used ||
        _clock().isAfter(session.expiresAt) ||
        file == null ||
        file.revision != session._revision) {
      throw StateError('Session de récupération invalide.');
    }
    session._used = true;
    _session = null;
    // Vérifie que la clé ouvre bien les données avant de toucher au verrou.
    final clear = await cipher.open(file.payload, session._dataKey, file.payloadContext);
    final master = await _masterLock(newPassword, session._dataKey, file.vaultId);
    _file = file.copyWith(master: master);
    _dataKey = session._dataKey;
    _entries = _decodeEntries(utf8.decode(clear));
    await _save();
    _lockedByUser = false;
    _setStatus(VaultStatus.unlocked);
  }

  // ---------------------------------------------------------------------

  void lock({bool byUser = false}) {
    if (_status != VaultStatus.unlocked) {
      // Une autorisation de récupération en cours est annulée, et les écrans
      // du parcours de récupération sont fermés.
      if (_session != null) {
        _session = null;
        notifyListeners();
      }
      return;
    }
    _lockedByUser = byUser;
    _dataKey = null;
    _entries = [];
    _setStatus(VaultStatus.locked);
  }

  /// Ajoute l'entrée, ou la remplace si une entrée de même id existe.
  Future<void> save(VaultEntry entry) async {
    _requireUnlocked();
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index == -1) {
      _entries.add(entry);
    } else {
      _entries[index] = entry;
    }
    _sort();
    await _save();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _requireUnlocked();
    _entries.removeWhere((e) => e.id == id);
    await _save();
    notifyListeners();
  }

  /// Renvoie `false` si [current] n'est pas le mot de passe maître actuel.
  /// La clé de coffre ne change pas : la récupération et le déverrouillage
  /// par le téléphone continuent de fonctionner.
  Future<bool> changeMasterPassword(String current, String next) async {
    _requireUnlocked();
    _checkMasterPassword(next);
    final file = _file!;
    final kek = await cipher.deriveMasterKey(current, file.master.salt, file.master.iterations);
    try {
      await cipher.open(file.master.wrappedKey, kek, file.masterContext);
    } on WrongPasswordException {
      return false;
    }
    _file = file.copyWith(master: await _masterLock(next, _dataKey!, file.vaultId));
    await _save();
    return true;
  }

  Future<MasterLock> _masterLock(String password, SecretKey dataKey, String vaultId) async {
    final salt = VaultCipher.randomBytes(16);
    final kek = await cipher.deriveMasterKey(password, salt, cipher.iterations);
    return MasterLock(
      salt: salt,
      iterations: cipher.iterations,
      wrappedKey: await cipher.seal(
        await dataKey.extractBytes(),
        kek,
        VaultFile.contextFor(vaultId, 'master'),
      ),
    );
  }

  Future<void> _open(VaultFile file, SecretKey dataKey) async {
    final clear = await cipher.open(file.payload, dataKey, file.payloadContext);
    _file = file;
    _dataKey = dataKey;
    _entries = _decodeEntries(utf8.decode(clear));
    _lockedByUser = false;
    _setStatus(VaultStatus.unlocked);
  }

  List<VaultEntry> _decodeEntries(String clear) {
    final list = (jsonDecode(clear) as List).cast<Map<String, dynamic>>();
    return list.map(VaultEntry.fromJson).toList()..sort(_byTitle);
  }

  Future<void> _save() async {
    final file = _file!;
    final clear = utf8.encode(jsonEncode(_entries.map((e) => e.toJson()).toList()));
    _file = file.copyWith(
      revision: file.revision + 1,
      payload: await cipher.seal(clear, _dataKey!, file.payloadContext),
    );
    await storage.write(_file!.encode());
  }

  Future<T> _withDeviceAuth<T>(Future<T> Function() action) async {
    _deviceAuthInProgress = true;
    try {
      return await action();
    } finally {
      _deviceAuthInProgress = false;
    }
  }

  void _checkMasterPassword(String password) {
    if (password.length < minMasterPasswordLength) {
      throw ArgumentError(
        'Le mot de passe maître doit contenir au moins '
        '$minMasterPasswordLength caractères.',
      );
    }
  }

  List<String> _checkAnswers(List<String> answers) {
    if (answers.length != recoveryQuestions.length) {
      throw ArgumentError('Les ${recoveryQuestions.length} réponses sont obligatoires.');
    }
    final normalized = answers.map(normalizeAnswer).toList();
    if (normalized.any((a) => a.length < minAnswerLength)) {
      throw ArgumentError('Chaque réponse doit contenir au moins $minAnswerLength caractères.');
    }
    return normalized;
  }

  static int _byTitle(VaultEntry a, VaultEntry b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());

  void _sort() => _entries.sort(_byTitle);

  void _requireUnlocked() {
    if (_status != VaultStatus.unlocked) throw StateError('Le coffre est verrouillé.');
  }

  void _setStatus(VaultStatus status) {
    _status = status;
    notifyListeners();
  }
}
