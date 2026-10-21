import 'package:flutter/material.dart';

import '../models/vault_entry.dart';
import '../services/device_unlock.dart';
import '../services/secure_clipboard.dart';
import '../services/terms_service.dart';
import '../services/vault_service.dart';
import '../widgets/brand.dart';
import 'about_screen.dart';
import 'entry_screen.dart';
import 'generator_sheet.dart';

/// Liste des identifiants du coffre déverrouillé, groupés par initiale.
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key, required this.vault, required this.terms});

  final VaultService vault;
  final TermsService terms;

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerDeviceUnlock());
  }

  Future<void> _offerDeviceUnlock() async {
    if (!mounted || !widget.vault.takeDeviceUnlockOffer()) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.fingerprint_rounded,
          size: 40,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Déverrouiller plus vite ?'),
        content: const Text(
          'Ouvrez votre coffre avec votre empreinte ou le code de votre téléphone. '
          'Le mot de passe maître restera toujours utilisable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Activer'),
          ),
        ],
      ),
    );
    if (accepted == true) await _setDeviceUnlock(true);
  }

  Future<void> _setDeviceUnlock(bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);
    String message;
    if (!enabled) {
      await widget.vault.disableDeviceUnlock();
      message = 'Déverrouillage par empreinte ou code désactivé';
    } else {
      try {
        await widget.vault.enableDeviceUnlock();
        message = 'Déverrouillage par empreinte ou code activé';
      } on DeviceUnlockCancelled {
        return;
      } on DeviceUnlockFailure {
        message =
            'Impossible d\'activer le déverrouillage. Vérifiez qu\'un code ou une empreinte '
            'est configuré sur le téléphone.';
      }
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Mot de passe de ${entry.title} copié. Effacé dans 30 s.')),
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
        titleSpacing: 16,
        title: const Row(
          children: [
            BrandMark(size: 30),
            SizedBox(width: 10),
            Flexible(
              child: FittedBox(fit: BoxFit.scaleDown, child: Wordmark(fontSize: 19)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Générateur',
            icon: const Icon(Icons.password_rounded),
            onPressed: () => showGeneratorSheet(context),
          ),
          IconButton(
            tooltip: 'Verrouiller',
            icon: const Icon(Icons.lock_rounded),
            onPressed: () => widget.vault.lock(byUser: true),
          ),
          PopupMenuButton<void>(
            tooltip: 'Plus d\'options',
            icon: const Icon(Icons.more_vert_rounded),
            itemBuilder: (_) => [
              if (widget.vault.deviceUnlockAvailable)
                CheckedPopupMenuItem(
                  checked: widget.vault.deviceUnlockEnabled,
                  onTap: () => _setDeviceUnlock(!widget.vault.deviceUnlockEnabled),
                  child: const Text('Déverrouiller avec l\'empreinte ou le code'),
                ),
              PopupMenuItem(
                onTap: _changeMasterPassword,
                child: const Text('Changer le mot de passe maître'),
              ),
              PopupMenuItem(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AboutScreen(terms: widget.terms)),
                ),
                child: const Text('À propos'),
              ),
            ],
          ),
          const SizedBox(width: 4),
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
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  key: const Key('search'),
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: switch (all.length) {
                      0 => 'Rechercher',
                      1 => 'Rechercher parmi 1 identifiant',
                      final n => 'Rechercher parmi $n identifiants',
                    },
                    prefixIcon: const Icon(Icons.search_rounded),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? _EmptyState(query: all.isEmpty ? null : _query)
                    : _GroupedList(entries: entries, onOpen: _open, onCopy: _copyPassword),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _open,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter'),
      ),
    );
  }
}

/// Identifiants groupés par initiale, un bloc par lettre.
class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.entries, required this.onOpen, required this.onCopy});

  final List<VaultEntry> entries;
  final void Function(VaultEntry) onOpen;
  final void Function(VaultEntry) onCopy;

  static String _letter(VaultEntry e) {
    final c = e.title.isEmpty ? '#' : e.title.characters.first.toUpperCase();
    return RegExp(r'[A-ZÀ-Ý]').hasMatch(c) ? c : '#';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = <String, List<VaultEntry>>{};
    for (final e in entries) {
      groups.putIfAbsent(_letter(e), () => []).add(e);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
      children: [
        for (final MapEntry(key: letter, value: items) in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
            child: Text(
              letter,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(indent: 72),
                  _EntryTile(
                    entry: items[i],
                    onTap: () => onOpen(items[i]),
                    onCopy: () => onCopy(items[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onTap, required this.onCopy});

  final VaultEntry entry;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            ShieldAvatar(label: entry.title),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (entry.username.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (entry.password.isNotEmpty)
              IconButton(
                tooltip: 'Copier le mot de passe',
                color: theme.colorScheme.primary,
                icon: const Icon(Icons.content_copy_rounded, size: 22),
                onPressed: onCopy,
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  /// `null` quand le coffre est vide ; sinon, la recherche sans résultat.
  const _EmptyState({required this.query});

  final String? query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = query == null;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(40, 24, 40, 104),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (empty)
              const BrandMark(size: 88)
            else
              Icon(Icons.search_off_rounded, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 20),
            Text(
              empty ? 'Votre coffre est vide' : 'Aucun résultat pour « ${query!.trim()} »',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              empty
                  ? 'Ajoutez votre premier identifiant. Seul le titre est obligatoire.'
                  : 'La recherche porte sur le titre, l\'identifiant et le site web.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
              validator: (v) => (v ?? '').length < min ? 'Au moins $min caractères' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmez le nouveau'),
              validator: (v) => v != _next.text ? 'Les deux mots de passe sont différents' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: _busy ? null : _submit,
          child: const Text('Modifier'),
        ),
      ],
    );
  }
}
