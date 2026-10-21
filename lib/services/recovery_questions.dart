/// Les trois questions de récupération, identiques pour tous les
/// utilisateurs. Elles ne peuvent être ni modifiées ni remplacées.
const recoveryQuestions = [
  'Quel était ton premier établissement scolaire ?',
  'Quel est le prénom de ton grand-parent préféré ?',
  'Quel est le prénom de ta première copine ?',
];

/// À incrémenter si les questions changent : les anciennes réponses ne
/// correspondraient plus aux questions affichées.
const recoveryQuestionsVersion = 1;

/// Longueur minimale d'une réponse normalisée.
const minAnswerLength = 2;

const _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', //
  'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
  'œ': 'oe', 'æ': 'ae',
  '’': "'", '‘': "'", 'ʼ': "'",
  '‐': '-', '‑': '-', '–': '-', '—': '-',
};

/// Normalise une réponse pour que de petites différences de saisie ne
/// bloquent pas la récupération : casse, espaces superflus, accents et
/// apostrophes typographiques.
///
/// « Lycée  Victor HUGO » et « lycee victor hugo » donnent la même réponse.
String normalizeAnswer(String answer) {
  final lower = answer.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}
