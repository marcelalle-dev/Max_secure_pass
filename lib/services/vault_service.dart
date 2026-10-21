import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/vault_entry.dart';
import 'device_unlock.dart';
import 'vault_cipher.dart';
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
}

/// État du coffre : création, déverrouillage, verrouillage et modifications.
/// Les entrées déchiffrées et la clé ne restent en mémoire que tant que le
/// coffre est déverrouillé.
class VaultService extends ChangeNotifier {
  VaultService({required this.storage, VaultCipher? cipher, this.deviceUnlock})
    : cipher = cipher ?? VaultCipher();

  static const minMasterPasswordLength = 8;

  final VaultStorage storage;
  final VaultCipher cipher;

  /// `null` si la plateforme ne permet pas le déverrouillage par le téléphone.
  final DeviceUnlock? deviceUnlock;

  VaultStatus _status = VaultStatus.loading;
  VaultKey? _key;
  List<VaultEntry> _entries = [];
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

  /// Entrées triées par titre.
  List<VaultEntry> get entries => List.unmodifiable(_entries);

  Future<void> init() async {
    final data = await storage.read();
    final device = deviceUnlock;
    if (device != null) {
      _deviceUnlockAvailable = await device.isAvailable();
      _deviceUnlockEnabled = data != null && await device.isEnabled();
    }
    _setStatus(data == null ? VaultStatus.uninitialized : VaultStatus.locked);
  }

  /// Vrai une seule fois, juste après la création du coffre, si le
  /// téléphone permet d'activer le déverrouillage par empreinte ou code.
  bool takeDeviceUnlockOffer() {
    final offer = _offerDeviceUnlock && _deviceUnlockAvailable && !_deviceUnlockEnabled;
    _offerDeviceUnlock = false;
    return offer;
  }

  Future<void> create(String masterPassword) async {
    if (masterPassword.length < minMasterPasswordLength) {
      throw ArgumentError(
        'Le mot de passe maître doit contenir au moins '
        '$minMasterPasswordLength caractères.',
      );
    }
    _key = await cipher.newKey(masterPassword);
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
      final (clear, key) = await cipher.decrypt(data, masterPassword);
      _open(clear, key);
      return true;
    } on WrongPasswordException {
      return false;
    }
  }

  /// Déverrouille avec l'empreinte ou le code du téléphone.
  Future<DeviceUnlockOutcome> unlockWithDevice() async {
    final device = deviceUnlock;
    final data = await storage.read();
    if (device == null || !_deviceUnlockEnabled || data == null) {
      return DeviceUnlockOutcome.disabled;
    }
    try {
      final keyBytes = await _withDeviceAuth(device.readKey);
      final (clear, key) = await cipher.decryptWithKey(data, keyBytes);
      _open(clear, key);
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
    final keyBytes = await _key!.secretKey.extractBytes();
    await _withDeviceAuth(() => device.enable(keyBytes));
    _deviceUnlockEnabled = true;
    notifyListeners();
  }

  Future<void> disableDeviceUnlock() async {
    await deviceUnlock?.disable();
    _deviceUnlockEnabled = false;
    notifyListeners();
  }

  void _open(String clear, VaultKey key) {
    final list = (jsonDecode(clear) as List).cast<Map<String, dynamic>>();
    _key = key;
    _entries = list.map(VaultEntry.fromJson).toList();
    _sort();
    _lockedByUser = false;
    _setStatus(VaultStatus.unlocked);
  }

  Future<T> _withDeviceAuth<T>(Future<T> Function() action) async {
    _deviceAuthInProgress = true;
    try {
      return await action();
    } finally {
      _deviceAuthInProgress = false;
    }
  }

  void lock({bool byUser = false}) {
    if (_status != VaultStatus.unlocked) return;
    _lockedByUser = byUser;
    _key = null;
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
  Future<bool> changeMasterPassword(String current, String next) async {
    _requireUnlocked();
    if (next.length < minMasterPasswordLength) {
      throw ArgumentError(
        'Le mot de passe maître doit contenir au moins '
        '$minMasterPasswordLength caractères.',
      );
    }
    try {
      await cipher.decrypt((await storage.read())!, current);
    } on WrongPasswordException {
      return false;
    }
    _key = await cipher.newKey(next);
    await _save();
    if (_deviceUnlockEnabled) {
      // L'ancienne clé enregistrée ne déchiffre plus le coffre.
      try {
        await enableDeviceUnlock();
      } on Exception {
        await disableDeviceUnlock();
      }
    }
    return true;
  }

  Future<void> _save() async {
    final clear = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await storage.write(await cipher.encrypt(clear, _key!));
  }

  void _sort() => _entries.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  void _requireUnlocked() {
    if (_status != VaultStatus.unlocked) throw StateError('Le coffre est verrouillé.');
  }

  void _setStatus(VaultStatus status) {
    _status = status;
    notifyListeners();
  }
}
