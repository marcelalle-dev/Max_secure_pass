import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/lock_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/vault_screen.dart';
import 'services/device_unlock.dart';
import 'services/terms_service.dart';
import 'services/vault_service.dart';
import 'services/vault_storage.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_fontLicenses);
  final vault = VaultService(storage: FileVaultStorage(), deviceUnlock: KeystoreDeviceUnlock())
    ..init();
  final terms = TermsService(FileTermsStore())..load();
  runApp(MaxSecurePassApp(vault: vault, terms: terms));
}

Stream<LicenseEntry> _fontLicenses() async* {
  for (final font in ['Sora', 'JetBrainsMono']) {
    final text = await rootBundle.loadString('assets/fonts/$font-OFL.txt');
    yield LicenseEntryWithLineBreaks([font], text);
  }
}

class MaxSecurePassApp extends StatefulWidget {
  const MaxSecurePassApp({super.key, required this.vault, required this.terms});

  final VaultService vault;
  final TermsService terms;

  @override
  State<MaxSecurePassApp> createState() => _MaxSecurePassAppState();
}

class _MaxSecurePassAppState extends State<MaxSecurePassApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Verrouille le coffre dès que l'application passe en arrière-plan.
    _lifecycle = AppLifecycleListener(
      onHide: () {
        // La saisie du code du téléphone passe par un écran système.
        if (!widget.vault.deviceAuthInProgress) widget.vault.lock();
      },
    );
    widget.vault.addListener(_onVaultChanged);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    widget.vault.removeListener(_onVaultChanged);
    super.dispose();
  }

  void _onVaultChanged() {
    // Au verrouillage, ferme les écrans ouverts (entrée, générateur…).
    if (widget.vault.status == VaultStatus.locked) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      // Les messages peuvent nommer un identifiant : on les efface aussi.
      _messengerKey.currentState?.clearSnackBars();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Max SecurePass',
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: ListenableBuilder(
        listenable: Listenable.merge([widget.vault, widget.terms]),
        builder: (context, _) {
          final vault = widget.vault, terms = widget.terms;
          if (!terms.loaded || vault.status == VaultStatus.loading) {
            return const Scaffold(body: SizedBox.expand());
          }
          // Les conditions doivent être acceptées avant tout le reste.
          if (!terms.accepted) return TermsScreen(terms: terms, acceptance: true);
          return switch (vault.status) {
            VaultStatus.loading => const Scaffold(body: SizedBox.expand()),
            VaultStatus.uninitialized || VaultStatus.locked => LockScreen(
              key: ValueKey(vault.status),
              vault: vault,
              terms: terms,
            ),
            VaultStatus.unlocked => VaultScreen(vault: vault, terms: terms),
          };
        },
      ),
    );
  }
}
