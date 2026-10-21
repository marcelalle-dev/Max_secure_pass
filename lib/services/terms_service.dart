import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../legal/terms.dart';

/// Mémorise l'acceptation des conditions d'utilisation.
abstract class TermsStore {
  Future<String?> read();
  Future<void> write(String data);
}

class FileTermsStore implements TermsStore {
  Future<File> _file() async =>
      File('${(await getApplicationSupportDirectory()).path}/terms_acceptance.json');

  @override
  Future<String?> read() async {
    final file = await _file();
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> write(String data) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(data, flush: true);
  }
}

/// Stockage en mémoire, utilisé par les tests.
class MemoryTermsStore implements TermsStore {
  MemoryTermsStore([this.data]);

  /// Conditions déjà acceptées dans leur version actuelle.
  MemoryTermsStore.accepted()
    : data = jsonEncode({'version': termsVersion, 'acceptedAt': '2026-10-21T10:00:00.000'});

  String? data;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String data) async => this.data = data;
}

class TermsService extends ChangeNotifier {
  TermsService(this.store);

  final TermsStore store;

  bool _loaded = false;
  int? _acceptedVersion;
  DateTime? _acceptedAt;

  bool get loaded => _loaded;

  /// La version actuelle des conditions a été acceptée.
  bool get accepted => _acceptedVersion == termsVersion;

  DateTime? get acceptedAt => accepted ? _acceptedAt : null;

  Future<void> load() async {
    final data = await store.read();
    if (data != null) {
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        _acceptedVersion = json['version'] as int;
        _acceptedAt = DateTime.parse(json['acceptedAt'] as String);
      } catch (_) {
        // Fichier illisible : on redemande l'acceptation.
        _acceptedVersion = null;
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> accept() async {
    final now = DateTime.now();
    await store.write(jsonEncode({'version': termsVersion, 'acceptedAt': now.toIso8601String()}));
    _acceptedVersion = termsVersion;
    _acceptedAt = now;
    notifyListeners();
  }
}
