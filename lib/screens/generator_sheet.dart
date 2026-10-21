import 'package:flutter/material.dart';

import '../services/password_generator.dart';
import '../services/secure_clipboard.dart';
import '../widgets/strength_meter.dart';

/// Ouvre le générateur. Avec [returnsPassword], un bouton « Utiliser »
/// renvoie le mot de passe généré à l'appelant.
Future<String?> showGeneratorSheet(BuildContext context, {bool returnsPassword = false}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => GeneratorSheet(returnsPassword: returnsPassword),
  );
}

class GeneratorSheet extends StatefulWidget {
  const GeneratorSheet({super.key, this.returnsPassword = false});

  final bool returnsPassword;

  @override
  State<GeneratorSheet> createState() => _GeneratorSheetState();
}

class _GeneratorSheetState extends State<GeneratorSheet> {
  var _options = const PasswordOptions();
  late String _password = generatePassword(_options);

  void _update(PasswordOptions options) {
    if (!options.hasCharset) return; // Garder au moins une catégorie.
    setState(() {
      _options = options;
      _password = generatePassword(options);
    });
  }

  Future<void> _copy() async {
    await SecureClipboard.copy(_password);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mot de passe copié (effacé dans 30 s)')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Générateur de mot de passe', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                _password,
                key: const Key('generatedPassword'),
                style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            StrengthMeter(password: _password),
            const SizedBox(height: 16),
            Text('Longueur : ${_options.length}'),
            Slider(
              value: _options.length.toDouble(),
              min: PasswordOptions.minLength.toDouble(),
              max: PasswordOptions.maxLength.toDouble(),
              divisions: PasswordOptions.maxLength - PasswordOptions.minLength,
              label: '${_options.length}',
              onChanged: (v) => _update(_options.copyWith(length: v.round())),
            ),
            SwitchListTile(
              title: const Text('Minuscules (a-z)'),
              value: _options.lowercase,
              onChanged: (v) => _update(_options.copyWith(lowercase: v)),
            ),
            SwitchListTile(
              title: const Text('Majuscules (A-Z)'),
              value: _options.uppercase,
              onChanged: (v) => _update(_options.copyWith(uppercase: v)),
            ),
            SwitchListTile(
              title: const Text('Chiffres (0-9)'),
              value: _options.digits,
              onChanged: (v) => _update(_options.copyWith(digits: v)),
            ),
            SwitchListTile(
              title: const Text('Symboles (!@#…)'),
              value: _options.symbols,
              onChanged: (v) => _update(_options.copyWith(symbols: v)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _update(_options),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Regénérer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: widget.returnsPassword
                      ? FilledButton.icon(
                          onPressed: () => Navigator.pop(context, _password),
                          icon: const Icon(Icons.check),
                          label: const Text('Utiliser'),
                        )
                      : FilledButton.icon(
                          onPressed: _copy,
                          icon: const Icon(Icons.copy),
                          label: const Text('Copier'),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
