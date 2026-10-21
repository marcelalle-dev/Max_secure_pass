import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Où le nombre de tentatives de récupération est mémorisé.
abstract class AttemptStore {
  Future<String?> read();
  Future<void> write(String data);
}

/// Stockage chiffré par le Keystore (sans authentification) : le compteur
/// ne peut pas être lu ni réinitialisé en modifiant un fichier de
/// l'application.
class SecureAttemptStore implements AttemptStore {
  static const _keyName = 'recovery_attempts';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(storageNamespace: 'maxsecurepass_guard'),
  );

  @override
  Future<String?> read() => _storage.read(key: _keyName);

  @override
  Future<void> write(String data) => _storage.write(key: _keyName, value: data);
}

/// Stockage en mémoire, utilisé par les tests.
class MemoryAttemptStore implements AttemptStore {
  String? data;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String data) async => this.data = data;
}

/// Limite les tentatives de récupération : quelques essais libres, puis un
/// délai qui augmente à chaque échec.
///
/// Chaque tentative est comptée **avant** la vérification et n'est effacée
/// qu'en cas de succès : fermer l'application pendant la vérification ne
/// permet pas d'échapper au compteur.
class RecoveryGuard {
  RecoveryGuard(this.store, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const freeAttempts = 3;
  static const delays = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(hours: 1),
  ];

  final AttemptStore store;
  final DateTime Function() _clock;

  Future<(int, DateTime?)> _load() async {
    final data = await store.read();
    if (data == null) return (0, null);
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final last = json['lastAttempt'] as String?;
      return (json['attempts'] as int, last == null ? null : DateTime.parse(last));
    } catch (_) {
      // Compteur illisible : on applique le délai maximal plutôt que de
      // repartir de zéro.
      return (freeAttempts + delays.length, _clock());
    }
  }

  static Duration delayAfter(int attempts) {
    if (attempts < freeAttempts) return Duration.zero;
    return delays[min(attempts - freeAttempts, delays.length - 1)];
  }

  /// Temps à attendre avant la prochaine tentative (zéro si permise).
  Future<Duration> remaining() async {
    final (attempts, last) = await _load();
    if (last == null) return Duration.zero;
    final now = _clock();
    final delay = delayAfter(attempts);
    // Horloge reculée : on ne raccourcit pas l'attente.
    if (now.isBefore(last)) return delay;
    final left = last.add(delay).difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// À appeler juste avant de vérifier des réponses.
  Future<void> recordAttempt() async {
    final (attempts, _) = await _load();
    await store.write(
      jsonEncode({'attempts': attempts + 1, 'lastAttempt': _clock().toIso8601String()}),
    );
  }

  Future<void> reset() => store.write(jsonEncode({'attempts': 0}));
}
