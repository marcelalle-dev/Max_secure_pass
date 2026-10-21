import 'dart:convert';

import 'vault_cipher.dart';

/// Verrou « mot de passe maître » : la clé de coffre chiffrée par la clé
/// dérivée du mot de passe.
class MasterLock {
  const MasterLock({required this.salt, required this.iterations, required this.wrappedKey});

  factory MasterLock.fromJson(Map<String, dynamic> json) => MasterLock(
    salt: base64Decode(json['salt'] as String),
    iterations: json['iterations'] as int,
    wrappedKey: Sealed.fromJson(json['wrappedKey'] as Map<String, dynamic>),
  );

  final List<int> salt;
  final int iterations;
  final Sealed wrappedKey;

  Map<String, dynamic> toJson() => {
    'kdf': 'pbkdf2-hmac-sha256',
    'salt': base64Encode(salt),
    'iterations': iterations,
    'wrappedKey': wrappedKey.toJson(),
  };
}

/// Verrou « questions de récupération » : la clé de coffre chiffrée par la
/// clé dérivée des trois réponses et du secret matériel du téléphone.
/// Les réponses elles-mêmes ne sont enregistrées nulle part.
class RecoveryLock {
  const RecoveryLock({
    required this.questionsVersion,
    required this.salts,
    required this.iterations,
    required this.wrappedKey,
  });

  factory RecoveryLock.fromJson(Map<String, dynamic> json) => RecoveryLock(
    questionsVersion: json['questionsVersion'] as int,
    salts: [for (final s in json['salts'] as List) base64Decode(s as String)],
    iterations: json['iterations'] as int,
    wrappedKey: Sealed.fromJson(json['wrappedKey'] as Map<String, dynamic>),
  );

  final int questionsVersion;

  /// Un sel par réponse.
  final List<List<int>> salts;
  final int iterations;
  final Sealed wrappedKey;

  Map<String, dynamic> toJson() => {
    'kdf': 'pbkdf2-hmac-sha256+hkdf-sha256',
    'questionsVersion': questionsVersion,
    'salts': [for (final s in salts) base64Encode(s)],
    'iterations': iterations,
    'wrappedKey': wrappedKey.toJson(),
  };
}

/// Fichier du coffre, format 2.
class VaultFile {
  const VaultFile({
    required this.vaultId,
    required this.revision,
    required this.master,
    required this.recovery,
    required this.payload,
  });

  factory VaultFile.decode(String data) {
    final json = jsonDecode(data) as Map<String, dynamic>;
    if (json['version'] != version) {
      throw FormatException('Version de coffre inattendue : ${json['version']}');
    }
    final recovery = json['recovery'] as Map<String, dynamic>?;
    return VaultFile(
      vaultId: json['vaultId'] as String,
      revision: json['revision'] as int,
      master: MasterLock.fromJson(json['master'] as Map<String, dynamic>),
      recovery: recovery == null ? null : RecoveryLock.fromJson(recovery),
      payload: Sealed.fromJson(json['payload'] as Map<String, dynamic>),
    );
  }

  static const version = 2;

  /// Version d'un fichier de coffre (1 : ancien format sans clé de coffre).
  static int versionOf(String data) => (jsonDecode(data) as Map<String, dynamic>)['version'] as int;

  /// Identifiant aléatoire du coffre, authentifié dans chaque verrou : un
  /// verrou copié depuis un autre coffre est refusé.
  final String vaultId;

  /// Incrémenté à chaque écriture.
  final int revision;
  final MasterLock master;
  final RecoveryLock? recovery;
  final Sealed payload;

  /// Données associées (AAD) d'un verrou ou des données de ce coffre.
  static String contextFor(String vaultId, String part) => 'maxsecurepass:v2:$vaultId:$part';

  String get masterContext => contextFor(vaultId, 'master');
  String get recoveryContext => contextFor(vaultId, 'recovery');
  String get payloadContext => contextFor(vaultId, 'payload');

  VaultFile copyWith({
    int? revision,
    MasterLock? master,
    RecoveryLock? recovery,
    Sealed? payload,
  }) => VaultFile(
    vaultId: vaultId,
    revision: revision ?? this.revision,
    master: master ?? this.master,
    recovery: recovery ?? this.recovery,
    payload: payload ?? this.payload,
  );

  /// Le même coffre, sans verrou de récupération.
  VaultFile withoutRecovery() => VaultFile(
    vaultId: vaultId,
    revision: revision + 1,
    master: master,
    recovery: null,
    payload: payload,
  );

  String encode() => jsonEncode({
    'version': version,
    'vaultId': vaultId,
    'revision': revision,
    'master': master.toJson(),
    if (recovery != null) 'recovery': recovery!.toJson(),
    'payload': payload.toJson(),
  });
}
