/// Éléments communs aux textes juridiques (conditions, confidentialité).
/// Sans dépendance à Flutter, pour pouvoir générer la page web.
library;

class LegalSection {
  const LegalSection(this.title, this.body);

  final String title;
  final String body;
}

const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', //
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

/// « 21 octobre 2026 ».
String formatFrenchDate(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';
