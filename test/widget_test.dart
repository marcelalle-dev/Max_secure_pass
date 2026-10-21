import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:maxsecurepass/main.dart';
import 'package:maxsecurepass/models/vault_entry.dart';
import 'package:maxsecurepass/services/terms_service.dart';
import 'package:maxsecurepass/services/vault_cipher.dart';
import 'package:maxsecurepass/services/vault_service.dart';
import 'package:maxsecurepass/services/vault_storage.dart';

import 'fake_device_unlock.dart';

void main() {
  late VaultService vault;

  setUp(() async {
    vault = VaultService(storage: MemoryVaultStorage(), cipher: VaultCipher(iterations: 1000));
    await vault.init();
  });

  Future<TermsService> acceptedTerms() async {
    final terms = TermsService(MemoryTermsStore.accepted());
    await terms.load();
    return terms;
  }

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
    await tester.pumpWidget(MaxSecurePassApp(vault: vault, terms: await acceptedTerms()));
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
    await tester.pumpWidget(MaxSecurePassApp(vault: vault, terms: await acceptedTerms()));
    await tester.pumpAndSettle();
    expect(find.text('Banque'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('search')), 'net');
    await tester.pumpAndSettle();
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Banque'), findsNothing);
  });

  testWidgets('propose l\'empreinte à l\'ouverture, pas après un verrouillage volontaire', (
    tester,
  ) async {
    usePhoneScreen(tester);
    final device = FakeDeviceUnlock();
    final storage = MemoryVaultStorage();
    VaultService service() =>
        VaultService(storage: storage, cipher: VaultCipher(iterations: 1000), deviceUnlock: device);
    await tester.runAsync(() async {
      final setup = service();
      await setup.init();
      await setup.create('correct horse battery');
      await setup.save(VaultEntry(title: 'Gmail'));
      await setup.enableDeviceUnlock();
      vault = service();
      await vault.init();
    });
    device.prompts = 0;

    // Ouverture de l'application : la demande s'affiche d'elle-même.
    await tester.pumpWidget(MaxSecurePassApp(vault: vault, terms: await acceptedTerms()));
    await settle(tester);
    expect(device.prompts, 1);
    expect(find.text('Gmail'), findsOneWidget);

    // Verrouillage volontaire : pas de nouvelle demande automatique.
    await tester.tap(find.byTooltip('Verrouiller'));
    await settle(tester);
    expect(device.prompts, 1);
    expect(find.text('Empreinte ou code'), findsOneWidget);

    await tester.ensureVisible(find.text('Empreinte ou code'));
    await tester.tap(find.text('Empreinte ou code'));
    await settle(tester);
    expect(device.prompts, 2);
    expect(find.text('Gmail'), findsOneWidget);
  });

  testWidgets('au premier lancement, les conditions doivent être acceptées', (tester) async {
    usePhoneScreen(tester);
    final store = MemoryTermsStore();
    final terms = TermsService(store);
    await terms.load();
    await tester.pumpWidget(MaxSecurePassApp(vault: vault, terms: terms));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenue dans Max SecurePass'), findsOneWidget);
    expect(find.text('Créer le coffre'), findsNothing);
    final button = find.widgetWithText(FilledButton, 'Accepter et continuer');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.tap(find.byKey(const Key('acceptTerms')));
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Créer le coffre'), findsOneWidget);
    expect(store.data, contains('"version":1'));
  });

  testWidgets('la page À propos affiche la version, les conditions et les licences', (
    tester,
  ) async {
    usePhoneScreen(tester);
    PackageInfo.setMockInitialValues(
      appName: 'Max SecurePass',
      packageName: 'dev.marcelalle.maxsecurepass',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await tester.pumpWidget(MaxSecurePassApp(vault: vault, terms: await acceptedTerms()));
    await tester.pumpAndSettle();

    // Accessible depuis l'écran de création/verrouillage.
    await tester.ensureVisible(find.text('À propos'));
    await tester.tap(find.text('À propos'));
    await tester.pumpAndSettle();
    expect(find.text('Version 1.0.0 (1)'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Conditions d\'utilisation'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conditions d\'utilisation'));
    await tester.pumpAndSettle();
    expect(find.textContaining('acceptée le 21 octobre 2026'), findsOneWidget);
    expect(find.byKey(const Key('acceptTerms')), findsNothing);
  });
}
