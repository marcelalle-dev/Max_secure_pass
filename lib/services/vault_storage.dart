import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Emplacement où le coffre chiffré est conservé.
abstract class VaultStorage {
  Future<String?> read();
  Future<void> write(String data);
}

/// Stocke le coffre chiffré dans le répertoire privé de l'application.
class FileVaultStorage implements VaultStorage {
  static const fileName = 'vault.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$fileName');
  }

  @override
  Future<String?> read() async {
    final file = await _file();
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> write(String data) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    // Écriture atomique : un plantage en cours d'écriture ne corrompt pas le coffre.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(data, flush: true);
    await tmp.rename(file.path);
  }
}

/// Stockage en mémoire, utilisé par les tests.
class MemoryVaultStorage implements VaultStorage {
  MemoryVaultStorage([this.data]);

  String? data;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String data) async => this.data = data;
}
