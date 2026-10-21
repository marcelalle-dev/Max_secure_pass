import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maxsecurepass/main.dart';
import 'package:maxsecurepass/models/vault_entry.dart';
import 'package:maxsecurepass/services/recovery_guard.dart';
import 'package:maxsecurepass/services/terms_service.dart';
import 'package:maxsecurepass/services/vault_cipher.dart';
import 'package:maxsecurepass/services/vault_service.dart';
import 'package:maxsecurepass/services/vault_storage.dart';

import 'fake_recovery_secret.dart';

const answers = ['Lycée Victor Hugo', 'Hélène', 'Aminata'];

void main() {
  late MemoryVaultStorage storage;
  late FakeRecoverySecretStore secret;
  late MemoryAttemptStore attempts;

  VaultService newVault() => VaultService(
    storage: storage,
    cipher: VaultCipher(iterations: 1000, recoveryIterations: 1000),
    recoverySecret: secret,
    attemptStore: attempts,
  );

  setUp(() {
    storage = MemoryVaultStorage();
    secret = FakeRecoverySecretStore();
    attempts = MemoryAttemptStore();
  });

  Future<Widget> app(VaultService vault) async {
    final terms = TermsService(MemoryTermsStore.accepted());
    await terms.load();
    return MaxSecurePassApp(vault: vault, terms: terms);
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  // Les dérivations de clé tournent dans des isolates : il faut du vrai temps.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> answer(WidgetTester tester, List<String> values) async {
    for (var i = 0; i < values.length; i++) {
      await tester.enterText(find.byKey(Key('recoveryAnswer$i')), values[i]);
    }
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
  }

  testWidgets('après la création du coffre, la configuration est obligatoire', (tester) async {
    phone(tester);
    late VaultService vault;
    await tester.runAsync(() async {
      vault = newVault();
      await vault.init();
      await vault.create('mot de passe maître');
    });
    await tester.pumpWidget(await app(vault));
    await tester.pumpAndSettle();

    expect(find.text('Préparez la récupération de votre coffre'), findsOneWidget);
    expect(find.text('Quel était ton premier établissement scolaire ?'), findsOneWidget);
    expect(find.text('Quel est le prénom de ton grand-parent préféré ?'), findsOneWidget);
    expect(find.text('Quel est le prénom de ta première copine ?'), findsOneWidget);

    // Le retour arrière ne permet pas de passer l'étape.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Préparez la récupération de votre coffre'), findsOneWidget);

    // Champs vides : enregistrement bloqué.
    await answer(tester, ['Lycée Victor Hugo', '', ' ']);
    await tapText(tester, 'Enregistrer mes réponses');
    await tester.pump();
    expect(find.text('Répondez à cette question'), findsNWidgets(2));
    expect(vault.recoveryConfigured, isFalse);
    expect(secret.prompts, 0);

    await answer(tester, answers);
    await tapText(tester, 'Enregistrer mes réponses');
    await settle(tester);
    expect(vault.recoveryConfigured, isTrue);
    expect(secret.prompts, 1);
    expect(find.textContaining('Votre coffre est vide'), findsOneWidget);
  });

  testWidgets('confirmation du téléphone annulée : on reste sur la configuration', (tester) async {
    phone(tester);
    late VaultService vault;
    await tester.runAsync(() async {
      vault = newVault();
      await vault.init();
      await vault.create('mot de passe maître');
    });
    await tester.pumpWidget(await app(vault));
    await tester.pumpAndSettle();
    secret.confirm = false;
    await answer(tester, answers);
    await tapText(tester, 'Enregistrer mes réponses');
    await settle(tester);
    expect(vault.recoveryConfigured, isFalse);
    expect(find.textContaining('confirmation par le téléphone est nécessaire'), findsOneWidget);
  });

  testWidgets('mot de passe oublié : parcours complet, données conservées', (tester) async {
    phone(tester);
    late VaultService vault;
    await tester.runAsync(() async {
      final setup = newVault();
      await setup.init();
      await setup.create('mot de passe maître');
      await setup.save(VaultEntry(title: 'Banque', password: 'Tr3s-Secret!'));
      await setup.save(VaultEntry(title: 'Gmail'));
      await setup.configureRecovery(answers);
      // Redémarrage de l'application.
      vault = newVault();
      await vault.init();
    });
    await tester.pumpWidget(await app(vault));
    await tester.pumpAndSettle();

    await tapText(tester, 'Mot de passe oublié ?');
    await tester.pumpAndSettle();
    expect(find.text('Retrouvez l\'accès à votre coffre'), findsOneWidget);
    await tapText(tester, 'Commencer');
    await tester.pumpAndSettle();

    // Une réponse fausse : message générique, sans dire laquelle.
    await answer(tester, ['Lycée Victor Hugo', 'Hélène', 'Fatou']);
    await tapText(tester, 'Vérifier mes réponses');
    await settle(tester);
    expect(find.byKey(const Key('recoveryError')), findsOneWidget);
    expect(find.textContaining('ne permettent pas d\'ouvrir le coffre'), findsOneWidget);
    expect(find.textContaining('question 3'), findsNothing);

    await answer(tester, [' lycee victor HUGO', 'helene', 'Aminata']);
    await tapText(tester, 'Vérifier mes réponses');
    await settle(tester);
    expect(find.text('Réponses vérifiées'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('newMasterPassword')), 'nouveau mot de passe');
    await tester.enterText(find.byKey(const Key('confirmNewMasterPassword')), 'autre chose');
    await tapText(tester, 'Enregistrer et ouvrir le coffre');
    await tester.pump();
    expect(find.text('Les deux mots de passe sont différents'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('confirmNewMasterPassword')),
      'nouveau mot de passe',
    );
    await tapText(tester, 'Enregistrer et ouvrir le coffre');
    await settle(tester);
    expect(find.text('Nouveau mot de passe enregistré'), findsOneWidget);
    expect(find.textContaining('Vos 2 identifiants sont intacts'), findsOneWidget);

    await tapText(tester, 'Ouvrir mon coffre');
    await tester.pumpAndSettle();
    expect(find.text('Banque'), findsOneWidget);
    expect(find.text('Gmail'), findsOneWidget);

    // Connexion avec le nouveau mot de passe.
    await tester.tap(find.byTooltip('Verrouiller'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('masterPassword')), 'nouveau mot de passe');
    await tapText(tester, 'Déverrouiller');
    await settle(tester);
    expect(find.text('Banque'), findsOneWidget);
  });

  testWidgets('tentatives répétées : le bouton est bloqué avec un compte à rebours', (
    tester,
  ) async {
    phone(tester);
    late VaultService vault;
    await tester.runAsync(() async {
      vault = newVault();
      await vault.init();
      await vault.create('mot de passe maître');
      await vault.configureRecovery(answers);
      vault.lock();
    });
    await tester.pumpWidget(await app(vault));
    await tester.pumpAndSettle();
    await tapText(tester, 'Mot de passe oublié ?');
    await tester.pumpAndSettle();
    await tapText(tester, 'Commencer');
    await tester.pumpAndSettle();

    for (var i = 0; i < RecoveryGuard.freeAttempts; i++) {
      await answer(tester, ['aaa', 'bbb', 'ccc']);
      await tapText(tester, 'Vérifier mes réponses');
      await settle(tester);
    }
    expect(find.textContaining('Prochain essai dans'), findsOneWidget);
    expect(find.textContaining('Trop de tentatives'), findsOneWidget);
    final button = find.ancestor(
      of: find.textContaining('Prochain essai dans'),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
  });

  testWidgets('quitter l\'application pendant la récupération ferme le parcours', (tester) async {
    phone(tester);
    late VaultService vault;
    await tester.runAsync(() async {
      vault = newVault();
      await vault.init();
      await vault.create('mot de passe maître');
      await vault.configureRecovery(answers);
      vault.lock();
    });
    await tester.pumpWidget(await app(vault));
    await tester.pumpAndSettle();
    await tapText(tester, 'Mot de passe oublié ?');
    await tester.pumpAndSettle();
    await tapText(tester, 'Commencer');
    await tester.pumpAndSettle();
    await answer(tester, answers);
    await tapText(tester, 'Vérifier mes réponses');
    await settle(tester);
    expect(find.text('Réponses vérifiées'), findsOneWidget);

    // Application mise en arrière-plan : l'autorisation est annulée.
    vault.lock();
    await tester.pumpAndSettle();
    expect(find.text('Réponses vérifiées'), findsNothing);
    expect(find.text('Déverrouiller'), findsOneWidget);
  });
}
