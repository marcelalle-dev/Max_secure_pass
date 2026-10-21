import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/terms_service.dart';
import '../services/vault_cipher.dart';
import '../widgets/brand.dart';
import 'terms_screen.dart';

/// Présentation de l'application : version, sécurité, conditions, licences.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, required this.terms});

  final TermsService terms;

  static String _thousands(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ' ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iterations = _thousands(VaultCipher.defaultIterations);

    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const SizedBox(height: 8),
          const Center(child: BrandMark(size: 96)),
          const SizedBox(height: 16),
          const Center(child: Wordmark(fontSize: 26)),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Your Passwords. Your Security.',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final info = snapshot.data;
                return Text(
                  info == null ? ' ' : 'Version ${info.version} (${info.buildNumber})',
                  key: const Key('appVersion'),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          _Section(
            title: 'Comment vos données sont protégées',
            children: [
              const _Fact(
                icon: Icons.phone_android_rounded,
                title: 'Uniquement sur ce téléphone',
                body:
                    'Pas de compte, pas de cloud, pas d\'accès à Internet. '
                    'La sauvegarde automatique d\'Android est désactivée.',
              ),
              const _Fact(
                icon: Icons.lock_rounded,
                title: 'Chiffrement AES-256-GCM',
                body: 'Le coffre entier est chiffré ; toute modification du fichier est détectée.',
              ),
              _Fact(
                icon: Icons.key_rounded,
                title: 'Clé dérivée du mot de passe maître',
                body:
                    'PBKDF2-HMAC-SHA256, $iterations itérations, pour ralentir '
                    'les tentatives de devinette.',
              ),
              const _Fact(
                icon: Icons.lock_reset_rounded,
                title: 'Récupération par questions',
                body:
                    'Vos réponses ne sont jamais enregistrées. Avec le code du téléphone, '
                    'elles permettent de choisir un nouveau mot de passe sans perdre vos données.',
              ),
              const _Fact(
                icon: Icons.fingerprint_rounded,
                title: 'Empreinte ou code, en option',
                body:
                    'La clé est alors protégée par le Keystore du téléphone, '
                    'qui exige votre empreinte ou votre code à chaque ouverture.',
              ),
              const _Fact(
                icon: Icons.visibility_off_rounded,
                title: 'Discrétion',
                body:
                    'Verrouillage dès que vous quittez l\'application, captures d\'écran '
                    'bloquées, presse-papiers vidé après 30 secondes.',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _Section(
            title: 'Équipe',
            children: [
              _Member(
                name: 'ALLE Sourou Marcel',
                role: 'Développeur web / mobile et concepteur des solutions numériques',
              ),
              Divider(indent: 72),
              _Member(name: 'HOUINDO Sessi Ange', role: 'Analyste qualité logicielle'),
            ],
          ),
          const SizedBox(height: 20),
          _Section(
            children: [
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Conditions d\'utilisation'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TermsScreen(terms: terms)),
                ),
              ),
              const Divider(indent: 56),
              ListTile(
                leading: const Icon(Icons.code_rounded),
                title: const Text('Licences des logiciels libres'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Max SecurePass',
                  applicationIcon: const Padding(
                    padding: EdgeInsets.all(12),
                    child: BrandMark(size: 56),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '© ${DateTime.now().year} Max SecurePass',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Text(title!, style: theme.textTheme.titleMedium),
          ),
        Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShieldAvatar.icon(icon, size: 30),
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

class _Member extends StatelessWidget {
  const _Member({required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              name.split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join(),
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  role,
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
