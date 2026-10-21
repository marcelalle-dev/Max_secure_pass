import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maxsecurepass/main.dart';
import 'package:maxsecurepass/models/vault_entry.dart';
import 'package:maxsecurepass/services/vault_cipher.dart';
import 'package:maxsecurepass/services/vault_service.dart';
import 'package:maxsecurepass/services/vault_storage.dart';

void main() {
  late VaultService vault;

  setUp(() async {
    vault = VaultService(storage: MemoryVaultStorage(), cipher: VaultCipher(iterations: 1000));
    await vault.init();
  });

  // La dérivation de clé tourne dans un isolate : il faut du vrai temps.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('crée le coffre, ajoute une entrée, verrouille et déverrouille', (tester) async {
    await tester.pumpWidget(MaxSecurePassApp(vault: vault));
    expect(find.text('Créer le coffre'), findsOneWidget);

    // Les mots de passe ne correspondent pas.
    await tester.enterText(find.byKey(const Key('masterPassword')), 'correct horse battery');
    await tester.enterText(find.byKey(const Key('confirmPassword')), 'autre chose');
    await tester.tap(find.text('Créer le coffre'));
    await tester.pump();
    expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('confirmPassword')), 'correct horse battery');
    await tester.tap(find.text('Créer le coffre'));
    await settle(tester);
    expect(find.textContaining('Votre coffre est vide'), findsOneWidget);

    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('title')), 'Gmail');
    await tester.enterText(find.byKey(const Key('username')), 'moi@example.com');
    await tester.enterText(find.byKey(const Key('password')), 's3cret!');
    await tester.tap(find.byTooltip('Enregistrer'));
    await settle(tester);
    expect(find.text('Gmail'), findsOneWidget);
    expect(find.text('moi@example.com'), findsOneWidget);

    await tester.tap(find.byTooltip('Verrouiller'));
    await tester.pumpAndSettle();
    expect(find.text('Déverrouiller'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('masterPassword')), 'mauvais mot de passe');
    await tester.tap(find.text('Déverrouiller'));
    await settle(tester);
    expect(find.text('Mot de passe incorrect'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('masterPassword')), 'correct horse battery');
    await tester.tap(find.text('Déverrouiller'));
    await settle(tester);
    expect(find.text('Gmail'), findsOneWidget);
  });

  testWidgets('recherche dans le coffre', (tester) async {
    await tester.runAsync(() async {
      await vault.create('correct horse battery');
      for (final title in ['Banque', 'Gmail', 'Netflix']) {
        await vault.save(VaultEntry(title: title));
      }
    });
    await tester.pumpWidget(MaxSecurePassApp(vault: vault));
    await tester.pumpAndSettle();
    expect(find.text('Banque'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'net');
    await tester.pumpAndSettle();
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Banque'), findsNothing);
  });
}
