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

  void usePhoneScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  // La dérivation de clé tourne dans un isolate : il faut du vrai temps.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('crée le coffre, ajoute une entrée, verrouille et déverrouille', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(MaxSecurePassApp(vault: vault));
    expect(find.text('Créer le coffre'), findsOneWidget);

    // Les mots de passe ne correspondent pas.
    await tester.enterText(find.byKey(const Key('masterPassword')), 'correct horse battery');
    await tester.enterText(find.byKey(const Key('confirmPassword')), 'autre chose');
    await tester.ensureVisible(find.text('Créer le coffre'));
    await tester.tap(find.text('Créer le coffre'));
    await tester.pump();
    expect(find.text('Les deux mots de passe sont différents'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('confirmPassword')), 'correct horse battery');
    await tester.ensureVisible(find.text('Créer le coffre'));
    await tester.tap(find.text('Créer le coffre'));
    await settle(tester);
    expect(find.textContaining('Votre coffre est vide'), findsOneWidget);

    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('title')), 'Gmail');
    await tester.enterText(find.byKey(const Key('username')), 'moi@example.com');
    await tester.enterText(find.byKey(const Key('password')), 's3cret!');
    await tester.ensureVisible(find.text('Ajouter au coffre'));
    await tester.tap(find.text('Ajouter au coffre'));
    await settle(tester);
    expect(find.text('Gmail'), findsOneWidget);
    expect(find.text('moi@example.com'), findsOneWidget);

    await tester.tap(find.byTooltip('Verrouiller'));
    await tester.pumpAndSettle();
    expect(find.text('Déverrouiller'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('masterPassword')), 'mauvais mot de passe');
    await tester.ensureVisible(find.text('Déverrouiller'));
    await tester.tap(find.text('Déverrouiller'));
    await settle(tester);
    expect(find.textContaining('Mot de passe incorrect'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('masterPassword')), 'correct horse battery');
    await tester.ensureVisible(find.text('Déverrouiller'));
    await tester.tap(find.text('Déverrouiller'));
    await settle(tester);
    expect(find.text('Gmail'), findsOneWidget);
  });

  testWidgets('recherche dans le coffre', (tester) async {
    usePhoneScreen(tester);
    await tester.runAsync(() async {
      await vault.create('correct horse battery');
      for (final title in ['Banque', 'Gmail', 'Netflix']) {
        await vault.save(VaultEntry(title: title));
      }
    });
    await tester.pumpWidget(MaxSecurePassApp(vault: vault));
    await tester.pumpAndSettle();
    expect(find.text('Banque'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('search')), 'net');
    await tester.pumpAndSettle();
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Banque'), findsNothing);
  });
}
