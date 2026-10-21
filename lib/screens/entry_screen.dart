import 'package:flutter/material.dart';

import '../models/vault_entry.dart';
import '../services/secure_clipboard.dart';
import '../services/vault_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand.dart';
import '../widgets/strength_meter.dart';
import 'generator_sheet.dart';

/// Création ou modification d'un identifiant.
class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key, required this.vault, this.entry});

  final VaultService vault;

  /// `null` pour créer un nouvel identifiant.
  final VaultEntry? entry;

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.entry?.title);
  late final _username = TextEditingController(text: widget.entry?.username);
  late final _password = TextEditingController(text: widget.entry?.password);
  late final _url = TextEditingController(text: widget.entry?.url);
  late final _notes = TextEditingController(text: widget.entry?.notes);
  bool _obscure = true;
  bool _saving = false;

  bool get _isNew => widget.entry == null;

  @override
  void dispose() {
    for (final c in [_title, _username, _password, _url, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final entry = (widget.entry ?? VaultEntry(title: '')).copyWith(
      title: _title.text.trim(),
      username: _username.text.trim(),
      password: _password.text,
      url: _url.text.trim(),
      notes: _notes.text,
    );
    await widget.vault.save(entry);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer ${widget.entry!.title} ?'),
        content: const Text('Cet identifiant sera définitivement retiré du coffre.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.vault.delete(widget.entry!.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _generate() async {
    final password = await showGeneratorSheet(context, returnsPassword: true);
    if (password != null) setState(() => _password.text = password);
  }

  Future<void> _copy(String value, String label) async {
    if (value.isEmpty) return;
    await SecureClipboard.copy(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label copié. Effacé dans 30 s.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Nouvel identifiant' : 'Identifiant'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                ListenableBuilder(
                  listenable: _title,
                  builder: (context, _) => ShieldAvatar(label: _title.text.trim()),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    key: const Key('title'),
                    controller: _title,
                    autofocus: _isNew,
                    textCapitalization: TextCapitalization.sentences,
                    style: theme.textTheme.titleMedium,
                    decoration: const InputDecoration(
                      labelText: 'Titre',
                      hintText: 'Gmail, banque, Wi-Fi…',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Donnez un titre à cet identifiant' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              key: const Key('username'),
              controller: _username,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Identifiant ou e-mail',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Copier l\'identifiant',
                  icon: const Icon(Icons.content_copy_rounded, size: 20),
                  onPressed: () => _copy(_username.text, 'Identifiant'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('password'),
              controller: _password,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontFamily: AppTheme.monoFamily, fontSize: 17),
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Afficher' : 'Masquer',
                  icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (_password.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              StrengthMeter(password: _password.text),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.password_rounded),
                  label: const Text('Générer'),
                ),
                TextButton.icon(
                  onPressed: _password.text.isEmpty
                      ? null
                      : () => _copy(_password.text, 'Mot de passe'),
                  icon: const Icon(Icons.content_copy_rounded, size: 20),
                  label: const Text('Copier'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('url'),
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Site web',
                prefixIcon: Icon(Icons.language_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('notes'),
              controller: _notes,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Notes', alignLabelWithHint: true),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + MediaQuery.viewInsetsOf(context).bottom),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.primary),
                  )
                : Text(_isNew ? 'Ajouter au coffre' : 'Enregistrer'),
          ),
        ),
      ),
    );
  }
}
