import 'package:flutter/material.dart';

import 'screens/lock_screen.dart';
import 'screens/vault_screen.dart';
import 'services/vault_service.dart';
import 'services/vault_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final vault = VaultService(storage: FileVaultStorage())..init();
  runApp(MaxSecurePassApp(vault: vault));
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
    const seed = Color(0xFF1B5E20);
    return MaterialApp(
      title: 'Max SecurePass',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seed)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      ),
      home: ListenableBuilder(
        listenable: widget.vault,
        builder: (context, _) => switch (widget.vault.status) {
          VaultStatus.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
          VaultStatus.uninitialized ||
          VaultStatus.locked => LockScreen(key: ValueKey(widget.vault.status), vault: widget.vault),
          VaultStatus.unlocked => VaultScreen(vault: widget.vault),
        },
      ),
    );
  }
}
