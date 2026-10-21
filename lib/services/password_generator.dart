import 'dart:math';

class PasswordOptions {
  const PasswordOptions({
    this.length = 20,
    this.lowercase = true,
    this.uppercase = true,
    this.digits = true,
    this.symbols = true,
  });

  static const minLength = 8;
  static const maxLength = 64;

  final int length;
  final bool lowercase;
  final bool uppercase;
  final bool digits;
  final bool symbols;

  bool get hasCharset => lowercase || uppercase || digits || symbols;

  PasswordOptions copyWith({
    int? length,
    bool? lowercase,
    bool? uppercase,
    bool? digits,
    bool? symbols,
  }) {
    return PasswordOptions(
      length: length ?? this.length,
      lowercase: lowercase ?? this.lowercase,
      uppercase: uppercase ?? this.uppercase,
      digits: digits ?? this.digits,
      symbols: symbols ?? this.symbols,
    );
  }
}

const _lower = 'abcdefghijklmnopqrstuvwxyz';
const _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const _digits = '0123456789';
const _symbols = r'!@#$%^&*()-_=+[]{};:,.<>?/~';

/// Génère un mot de passe aléatoire contenant au moins un caractère de
/// chaque catégorie demandée.
String generatePassword(PasswordOptions options, {Random? random}) {
  if (!options.hasCharset) {
    throw ArgumentError('Au moins une catégorie de caractères est requise.');
  }
  final rng = random ?? Random.secure();
  final sets = [
    if (options.lowercase) _lower,
    if (options.uppercase) _upper,
    if (options.digits) _digits,
    if (options.symbols) _symbols,
  ];
  final all = sets.join();
  final length = max(options.length, sets.length);
  final chars = [
    for (final set in sets) set[rng.nextInt(set.length)],
    for (var i = sets.length; i < length; i++) all[rng.nextInt(all.length)],
  ]..shuffle(rng);
  return chars.join();
}

enum PasswordStrength {
  veryWeak('Très faible'),
  weak('Faible'),
  medium('Moyen'),
  strong('Fort'),
  veryStrong('Très fort');

  const PasswordStrength(this.label);

  final String label;
}

/// Estime l'entropie (en bits) d'après la longueur et les catégories de
/// caractères utilisées.
double passwordEntropy(String password) {
  if (password.isEmpty) return 0;
  var pool = 0;
  if (password.contains(RegExp('[a-z]'))) pool += 26;
  if (password.contains(RegExp('[A-Z]'))) pool += 26;
  if (password.contains(RegExp('[0-9]'))) pool += 10;
  if (password.contains(RegExp('[^a-zA-Z0-9]'))) pool += 33;
  return password.length * log(pool) / ln2;
}

PasswordStrength passwordStrength(String password) {
  final bits = passwordEntropy(password);
  if (bits < 28) return PasswordStrength.veryWeak;
  if (bits < 40) return PasswordStrength.weak;
  if (bits < 60) return PasswordStrength.medium;
  if (bits < 100) return PasswordStrength.strong;
  return PasswordStrength.veryStrong;
}
