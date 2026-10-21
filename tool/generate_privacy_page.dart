// Génère la page web de la politique de confidentialité :
//   dart run tool/generate_privacy_page.dart
import 'dart:io';

import 'package:maxsecurepass/legal/privacy_page.dart';

const output = 'docs/politique-de-confidentialite.html';

void main() {
  File(output).writeAsStringSync(renderPrivacyPage());
  stdout.writeln('Écrit : $output');
}
