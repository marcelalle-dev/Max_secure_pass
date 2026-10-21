import 'package:flutter/material.dart';

import '../services/password_generator.dart';
import '../services/secure_clipboard.dart';
import '../widgets/password_text.dart';
import '../widgets/strength_meter.dart';

/// Ouvre le générateur. Avec [returnsPassword], le bouton « Utiliser »
/// renvoie le mot de passe généré à l'appelant.
Future<String?> showGeneratorSheet(BuildContext context, {bool returnsPassword = false}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Mot de passe copié. Effacé dans 30 s.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nouveau mot de passe', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Container(
              key: const Key('generatedPassword'),
              constraints: const BoxConstraints(minHeight: 88),
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: PasswordText(
                      _password,
                      fontSize: switch (_options.length) {
                        <= 16 => 22,
                        <= 22 => 18,
                        _ => 15,
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Regénérer',
                    color: scheme.primary,
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => _update(_options),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            StrengthMeter(password: _password),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Longueur', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  '${_options.length} caractères',
                  style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
                ),
              ],
            ),
            Slider(
              value: _options.length.toDouble(),
              min: PasswordOptions.minLength.toDouble(),
              max: PasswordOptions.maxLength.toDouble(),
              divisions: PasswordOptions.maxLength - PasswordOptions.minLength,
              label: '${_options.length}',
              padding: const EdgeInsets.symmetric(vertical: 12),
              onChanged: (v) => _update(_options.copyWith(length: v.round())),
            ),
            const SizedBox(height: 8),
            Text('Caractères', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (i, chip) in [
                  _toggle(
                    'a–z',
                    'Minuscules',
                    _options.lowercase,
                    (v) => _options.copyWith(lowercase: v),
                  ),
                  _toggle(
                    'A–Z',
                    'Majuscules',
                    _options.uppercase,
                    (v) => _options.copyWith(uppercase: v),
                  ),
                  _toggle('0–9', 'Chiffres', _options.digits, (v) => _options.copyWith(digits: v)),
                  _toggle(
                    '!@#',
                    'Symboles',
                    _options.symbols,
                    (v) => _options.copyWith(symbols: v),
                  ),
                ].indexed) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: chip)],
              ],
            ),
            const SizedBox(height: 28),
            widget.returnsPassword
                ? FilledButton.icon(
                    onPressed: () => Navigator.pop(context, _password),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Utiliser ce mot de passe'),
                  )
                : FilledButton.icon(
                    onPressed: _copy,
                    icon: const Icon(Icons.content_copy_rounded),
                    label: const Text('Copier'),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _toggle(String sample, String name, bool selected, PasswordOptions Function(bool) change) {
    return Tooltip(
      message: name,
      child: FilterChip(
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(vertical: 8),
        label: SizedBox(
          width: double.infinity,
          child: Text(sample, textAlign: TextAlign.center),
        ),
        selected: selected,
        onSelected: (v) => _update(change(v)),
      ),
    );
  }
}
