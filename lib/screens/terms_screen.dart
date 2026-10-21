import 'package:flutter/material.dart';

import '../legal/terms.dart';
import '../services/terms_service.dart';
import '../widgets/brand.dart';

/// Conditions d'utilisation. Avec [acceptance], l'écran sert à les faire
/// accepter au démarrage ; sinon il les affiche en lecture seule.
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key, required this.terms, this.acceptance = false});

  final TermsService terms;
  final bool acceptance;

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _checked = false;
  bool _saving = false;

  bool get _accepting => widget.acceptance;

  Future<void> _accept() async {
    setState(() => _saving = true);
    // L'application passe d'elle-même à l'écran suivant.
    await widget.terms.accept();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final acceptedAt = widget.terms.acceptedAt;

    final content = <Widget>[
      if (_accepting) ...[
        const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 56)),
        const SizedBox(height: 20),
        Text('Bienvenue dans Max SecurePass', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Avant de créer votre coffre, prenez connaissance des conditions d\'utilisation.',
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        for (final (icon, title, body) in termsHighlights)
          _Highlight(icon: icon, title: title, body: body),
        const SizedBox(height: 12),
      ],
      Text(
        'Conditions d\'utilisation',
        style: _accepting ? theme.textTheme.titleLarge : theme.textTheme.headlineSmall,
      ),
      const SizedBox(height: 4),
      Text(
        'Version $termsVersion du ${formatFrenchDate(termsDate)}'
        '${!_accepting && acceptedAt != null ? ', acceptée le ${formatFrenchDate(acceptedAt)}' : ''}',
        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      for (final section in termsSections) ...[
        const SizedBox(height: 20),
        Text(section.title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(section.body, style: theme.textTheme.bodyMedium),
      ],
    ];

    return Scaffold(
      appBar: _accepting ? null : AppBar(title: const Text('Conditions d\'utilisation')),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: EdgeInsets.fromLTRB(24, _accepting ? 32 : 8, 24, 32),
              children: content,
            ),
          ),
        ),
      ),
      bottomNavigationBar: !_accepting
          ? null
          : Material(
              color: scheme.surface,
              shape: Border(top: BorderSide(color: scheme.outlineVariant)),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CheckboxListTile(
                        key: const Key('acceptTerms'),
                        value: _checked,
                        onChanged: _saving ? null : (v) => setState(() => _checked = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('J\'ai lu et j\'accepte les conditions d\'utilisation'),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: FilledButton(
                          onPressed: _checked && !_saving ? _accept : null,
                          child: const Text('Accepter et continuer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: ShieldAvatar.icon(icon)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
