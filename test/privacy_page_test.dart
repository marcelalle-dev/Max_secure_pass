import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxsecurepass/legal/privacy.dart';
import 'package:maxsecurepass/legal/privacy_page.dart';

void main() {
  test('la page publiée correspond au texte de l\'application', () {
    expect(
      File('docs/politique-de-confidentialite.html').readAsStringSync(),
      renderPrivacyPage(),
      reason: 'Relancez : dart run tool/generate_privacy_page.dart',
    );
  });

  test('la page contient le contact et toutes les sections', () {
    final html = renderPrivacyPage();
    expect(html, contains('mailto:$contactEmail'));
    for (final section in privacySections) {
      expect(html, contains(section.title));
    }
    // Aucune ressource externe chargée.
    expect(html, isNot(contains('<link')));
    expect(html, isNot(contains('<script')));
    expect(html, isNot(contains('src="http')));
  });
}
