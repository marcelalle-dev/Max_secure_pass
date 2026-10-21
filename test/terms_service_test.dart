import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxsecurepass/legal/terms.dart';
import 'package:maxsecurepass/services/terms_service.dart';

void main() {
  test('rien d\'accepté au premier lancement', () async {
    final terms = TermsService(MemoryTermsStore());
    await terms.load();
    expect(terms.loaded, isTrue);
    expect(terms.accepted, isFalse);
  });

  test('l\'acceptation est mémorisée', () async {
    final store = MemoryTermsStore();
    await (TermsService(store)..load()).accept();
    final reopened = TermsService(store);
    await reopened.load();
    expect(reopened.accepted, isTrue);
    expect(reopened.acceptedAt, isNotNull);
  });

  test('une nouvelle version des conditions doit être acceptée', () async {
    final store = MemoryTermsStore(
      jsonEncode({'version': termsVersion - 1, 'acceptedAt': '2026-01-01T00:00:00.000'}),
    );
    final terms = TermsService(store);
    await terms.load();
    expect(terms.accepted, isFalse);
    expect(terms.acceptedAt, isNull);
  });

  test('un fichier illisible redemande l\'acceptation', () async {
    final terms = TermsService(MemoryTermsStore('{"version":"x"}'));
    await terms.load();
    expect(terms.accepted, isFalse);
  });

  test('date en français', () {
    expect(formatFrenchDate(DateTime(2026, 8, 1)), '1 août 2026');
  });
}
