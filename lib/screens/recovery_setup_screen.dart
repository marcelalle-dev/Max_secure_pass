import 'package:flutter/material.dart';

import '../services/device_unlock.dart';
import '../services/vault_service.dart';
import '../widgets/brand.dart';
import '../widgets/notice.dart';
import '../widgets/recovery_questions_form.dart';

/// Configuration obligatoire des trois réponses de récupération, juste
/// après la création du coffre (ou sa mise à jour). Elle ne peut pas être
/// passée.
class RecoverySetupScreen extends StatefulWidget {
  const RecoverySetupScreen({super.key, required this.vault});

  final VaultService vault;

  @override
  State<RecoverySetupScreen> createState() => _RecoverySetupScreenState();
}

class _RecoverySetupScreenState extends State<RecoverySetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _answers = RecoveryQuestionsForm.createControllers();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _answers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.vault.configureRecovery([for (final c in _answers) c.text]);
      // L'application passe d'elle-même au coffre.
    } on DeviceUnlockCancelled {
      _fail(
        'La confirmation par le téléphone est nécessaire : elle empêche quiconque '
        'n\'a pas votre téléphone de tester des réponses.',
      );
    } on DeviceUnlockFailure {
      _fail(
        'Le téléphone n\'a pas pu protéger vos réponses. Vérifiez qu\'un code de '
        'verrouillage d\'écran est configuré (Paramètres > Sécurité), puis réessayez.',
      );
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                // Pas de ListView : les champs hors écran échapperaient à la validation.
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: ShieldAvatar.icon(Icons.lock_reset_rounded, size: 52),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Préparez la récupération de votre coffre',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Si vous oubliez votre mot de passe maître, ces trois réponses et le code '
                        'de votre téléphone vous permettront d\'en choisir un nouveau, sans perdre '
                        'vos identifiants.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      const Notice(
                        text:
                            'Choisissez des réponses dont vous vous souviendrez exactement. '
                            'Majuscules, accents et espaces en trop ne comptent pas.',
                      ),
                      const SizedBox(height: 28),
                      RecoveryQuestionsForm(
                        controllers: _answers,
                        enabled: !_busy,
                        onSubmitted: _save,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 20),
                        Notice(text: _error!, tone: NoticeTone.error),
                      ],
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: _busy
                            ? SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: scheme.primary,
                                ),
                              )
                            : const Text('Enregistrer mes réponses'),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Le code ou l\'empreinte du téléphone vous sera demandé. Vos réponses ne '
                        'sont enregistrées nulle part, pas même chiffrées.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
