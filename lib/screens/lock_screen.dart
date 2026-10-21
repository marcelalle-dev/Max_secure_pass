import 'package:flutter/material.dart';

import '../services/vault_service.dart';
import '../widgets/strength_meter.dart';

/// Création du coffre (premier lancement) ou déverrouillage.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.vault});

  final VaultService vault;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  bool get _creating => widget.vault.status == VaultStatus.uninitialized;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    if (_creating) {
      await widget.vault.create(_password.text);
    } else if (!await widget.vault.unlock(_password.text)) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Mot de passe incorrect';
      });
      _password.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.shield_outlined, size: 72, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Max SecurePass',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                    Text(
                      'Your Passwords. Your Security.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    if (_creating) ...[
                      Text(
                        'Choisissez un mot de passe maître. Il chiffre tout votre coffre '
                        'et ne peut pas être récupéré en cas d\'oubli.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      key: const Key('masterPassword'),
                      controller: _password,
                      obscureText: _obscure,
                      autofocus: true,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe maître',
                        border: const OutlineInputBorder(),
                        errorText: _error,
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      onChanged: _creating ? (_) => setState(() {}) : null,
                      onFieldSubmitted: _creating ? null : (_) => _submit(),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Saisissez votre mot de passe';
                        if (_creating && value.length < VaultService.minMasterPasswordLength) {
                          return 'Au moins ${VaultService.minMasterPasswordLength} caractères';
                        }
                        return null;
                      },
                    ),
                    if (_creating) ...[
                      const SizedBox(height: 8),
                      StrengthMeter(password: _password.text),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('confirmPassword'),
                        controller: _confirm,
                        obscureText: _obscure,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Confirmer le mot de passe',
                          border: OutlineInputBorder(),
                        ),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) => value != _password.text
                            ? 'Les mots de passe ne correspondent pas'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_creating ? 'Créer le coffre' : 'Déverrouiller'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
