import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/lock_screen.dart';
import 'screens/vault_screen.dart';
import 'services/vault_service.dart';
import 'services/vault_storage.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_fontLicenses);
  final vault = VaultService(storage: FileVaultStorage())..init();
  runApp(MaxSecurePassApp(vault: vault));
}

Stream<LicenseEntry> _fontLicenses() async* {
  for (final font in ['Sora', 'JetBrainsMono']) {
    final text = await rootBundle.loadString('assets/fonts/$font-OFL.txt');
    yield LicenseEntryWithLineBreaks([font], text);
  }
}

class MaxSecurePassApp extends StatefulWidget {
  const MaxSecurePassApp({super.key, required this.vault});

  final VaultService vault;

  @override
  State<MaxSecurePassApp> createState() => _MaxSecurePassAppState();
}

class _MaxSecurePassAppState extends State<MaxSecurePassApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Verrouille le coffre dès que l'application passe en arrière-plan.
    _lifecycle = AppLifecycleListener(onHide: widget.vault.lock);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Max SecurePass',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: ListenableBuilder(
        listenable: widget.vault,
        builder: (context, _) => switch (widget.vault.status) {
          VaultStatus.loading => const Scaffold(body: SizedBox.expand()),
          VaultStatus.uninitialized ||
          VaultStatus.locked => LockScreen(key: ValueKey(widget.vault.status), vault: widget.vault),
          VaultStatus.unlocked => VaultScreen(vault: widget.vault),
        },
      ),
    );
  }
}
