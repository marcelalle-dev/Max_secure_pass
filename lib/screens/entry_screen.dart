import 'package:flutter/material.dart';

import '../models/vault_entry.dart';
import '../services/secure_clipboard.dart';
import '../services/vault_service.dart';
import '../widgets/strength_meter.dart';
import 'generator_sheet.dart';

/// Création ou modification d'une entrée du coffre.
class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key, required this.vault, this.entry});

  final VaultService vault;

  /// `null` pour créer une nouvelle entrée.
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
        title: const Text('Supprimer cette entrée ?'),
        content: Text('« ${widget.entry!.title} » sera définitivement supprimée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copié (effacé dans 30 s)')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Nouvelle entrée' : 'Modifier'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          IconButton(tooltip: 'Enregistrer', icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('title'),
              controller: _title,
              autofocus: _isNew,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Titre',
                hintText: 'ex. : Gmail, Banque…',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Le titre est obligatoire' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('username'),
              controller: _username,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Identifiant / e-mail',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Copier l\'identifiant',
                  icon: const Icon(Icons.copy),
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
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _obscure ? 'Afficher' : 'Masquer',
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    IconButton(
                      tooltip: 'Générer',
                      icon: const Icon(Icons.casino_outlined),
                      onPressed: _generate,
                    ),
                    IconButton(
                      tooltip: 'Copier le mot de passe',
                      icon: const Icon(Icons.copy),
                      onPressed: () => _copy(_password.text, 'Mot de passe'),
                    ),
                  ],
                ),
              ),
            ),
            if (_password.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              StrengthMeter(password: _password.text),
            ],
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('url'),
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Site web',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('notes'),
              controller: _notes,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
