import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/vault_entry.dart';
import 'vault_cipher.dart';
import 'vault_storage.dart';

enum VaultStatus { loading, uninitialized, locked, unlocked }

/// État du coffre : création, déverrouillage, verrouillage et modifications.
/// Les entrées déchiffrées et la clé ne restent en mémoire que tant que le
/// coffre est déverrouillé.
class VaultService extends ChangeNotifier {
  VaultService({required this.storage, VaultCipher? cipher}) : cipher = cipher ?? VaultCipher();

  static const minMasterPasswordLength = 8;

  final VaultStorage storage;
  final VaultCipher cipher;

  VaultStatus _status = VaultStatus.loading;
  VaultKey? _key;
  List<VaultEntry> _entries = [];

  VaultStatus get status => _status;

  /// Entrées triées par titre.
  List<VaultEntry> get entries => List.unmodifiable(_entries);

  Future<void> init() async {
    final data = await storage.read();
    _setStatus(data == null ? VaultStatus.uninitialized : VaultStatus.locked);
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
    _setStatus(VaultStatus.unlocked);
  }

  /// Renvoie `false` si le mot de passe est incorrect.
  Future<bool> unlock(String masterPassword) async {
    final data = await storage.read();
    if (data == null) return false;
    try {
      final (clear, key) = await cipher.decrypt(data, masterPassword);
      final list = (jsonDecode(clear) as List).cast<Map<String, dynamic>>();
      _key = key;
      _entries = list.map(VaultEntry.fromJson).toList();
      _sort();
      _setStatus(VaultStatus.unlocked);
      return true;
    } on WrongPasswordException {
      return false;
    }
  }

  void lock() {
    if (_status != VaultStatus.unlocked) return;
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
