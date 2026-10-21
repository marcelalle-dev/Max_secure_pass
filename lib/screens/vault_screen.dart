import 'package:flutter/material.dart';

import '../models/vault_entry.dart';
import '../services/secure_clipboard.dart';
import '../services/vault_service.dart';
import 'entry_screen.dart';
import 'generator_sheet.dart';

/// Liste des entrées du coffre déverrouillé.
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key, required this.vault});

  final VaultService vault;

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  String _query = '';

  void _open([VaultEntry? entry]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryScreen(vault: widget.vault, entry: entry),
      ),
    );
  }

  Future<void> _copyPassword(VaultEntry entry) async {
    await SecureClipboard.copy(entry.password);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mot de passe de « ${entry.title} » copié (effacé dans 30 s)')),
    );
  }

  Future<void> _changeMasterPassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangeMasterPasswordDialog(vault: widget.vault),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mot de passe maître modifié')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Max SecurePass'),
        actions: [
          IconButton(
            tooltip: 'Générateur',
            icon: const Icon(Icons.casino_outlined),
            onPressed: () => showGeneratorSheet(context),
          ),
          IconButton(
            tooltip: 'Verrouiller',
            icon: const Icon(Icons.lock_outline),
            onPressed: widget.vault.lock,
          ),
          PopupMenuButton<void>(
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: _changeMasterPassword,
                child: const Text('Changer le mot de passe maître'),
              ),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.vault,
        builder: (context, _) {
          final all = widget.vault.entries;
          final entries = all.where((e) => e.matches(_query)).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SearchBar(
                  hintText: 'Rechercher',
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? _EmptyState(searching: all.isNotEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: entries.length,
                        itemBuilder: (context, i) {
                          final entry = entries[i];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(entry.title.characters.first.toUpperCase()),
                            ),
                            title: Text(entry.title),
                            subtitle: entry.username.isEmpty ? null : Text(entry.username),
                            trailing: entry.password.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Copier le mot de passe',
                                    icon: const Icon(Icons.copy),
                                    onPressed: () => _copyPassword(entry),
                                  ),
                            onTap: () => _open(entry),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _open,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off : Icons.key_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              searching
                  ? 'Aucun résultat'
                  : 'Votre coffre est vide.\nAjoutez votre premier mot de passe.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangeMasterPasswordDialog extends StatefulWidget {
  const _ChangeMasterPasswordDialog({required this.vault});

  final VaultService vault;

  @override
  State<_ChangeMasterPasswordDialog> createState() => _ChangeMasterPasswordDialogState();
}

class _ChangeMasterPasswordDialogState extends State<_ChangeMasterPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.vault.changeMasterPassword(_current.text, _next.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = 'Mot de passe incorrect';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const min = VaultService.minMasterPasswordLength;
    return AlertDialog(
      title: const Text('Changer le mot de passe maître'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Mot de passe actuel', errorText: _error),
            ),
            TextFormField(
              controller: _next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
              validator: (v) => (v ?? '').length < min ? 'Au moins $min caractères' : null,
            ),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmer'),
              validator: (v) => v != _next.text ? 'Les mots de passe ne correspondent pas' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _busy ? null : _submit, child: const Text('Valider')),
      ],
    );
  }
}
