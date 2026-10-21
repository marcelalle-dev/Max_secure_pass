import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../services/vault_service.dart';
import '../widgets/brand.dart';
import '../widgets/notice.dart';
import '../widgets/recovery_questions_form.dart';
import '../widgets/strength_meter.dart';

/// « 30 s », « 4 min 05 s », « 1 h ».
String formatWait(Duration d) {
  final seconds = d.inSeconds + (d.inMilliseconds % 1000 > 0 ? 1 : 0);
  if (seconds < 60) return '$seconds s';
  if (seconds < 3600) {
    final s = seconds % 60;
    return s == 0
        ? '${seconds ~/ 60} min'
        : '${seconds ~/ 60} min ${s.toString().padLeft(2, '0')} s';
  }
  final m = (seconds % 3600) ~/ 60;
  return m == 0 ? '${seconds ~/ 3600} h' : '${seconds ~/ 3600} h ${m.toString().padLeft(2, '0')}';
}

/// Mise en page commune aux écrans du parcours.
class _FlowPage extends StatelessWidget {
  const _FlowPage({required this.title, required this.children, this.bottom, this.canPop = true});

  final String title;
  final List<Widget> children;
  final Widget? bottom;
  final bool canPop;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: canPop,
      child: Scaffold(
        appBar: AppBar(title: Text(title), automaticallyImplyLeading: canPop),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            // Pas de ListView : ses éléments hors écran ne sont pas construits, et
            // les champs non construits échapperaient à la validation du formulaire.
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ),
        bottomNavigationBar: bottom == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    8,
                    24,
                    12 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: bottom,
                ),
              ),
      ),
    );
  }
}

/// Point d'entrée « Mot de passe oublié ? » : explique la démarche.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key, required this.vault});

  final VaultService vault;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final configured = vault.recoveryConfigured;
    return _FlowPage(
      title: 'Mot de passe oublié',
      bottom: configured
          ? FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RecoveryVerifyScreen(vault: vault)),
              ),
              child: const Text('Commencer'),
            )
          : null,
      children: [
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.centerLeft,
          child: ShieldAvatar.icon(Icons.lock_reset_rounded, size: 52),
        ),
        const SizedBox(height: 20),
        Text('Retrouvez l\'accès à votre coffre', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        if (!configured) ...[
          Text(
            'La récupération par questions n\'a pas été configurée pour ce coffre. '
            'Seul votre mot de passe maître peut l\'ouvrir.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          const Notice(
            text:
                'Si vous retrouvez votre mot de passe, ouvrez le coffre : la configuration '
                'des questions vous sera proposée.',
          ),
        ] else ...[
          Text(
            'Vous allez choisir un nouveau mot de passe maître. Tous vos identifiants sont '
            'conservés.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          for (final (i, step) in [
            'Répondez aux trois questions personnelles.',
            'Confirmez avec le code ou l\'empreinte du téléphone.',
            'Choisissez votre nouveau mot de passe maître.',
          ].indexed)
            _Step(number: i + 1, text: step),
          const SizedBox(height: 8),
          const Notice(
            icon: Icons.timer_outlined,
            text:
                'Après trois essais incorrects, un délai d\'attente croissant s\'applique '
                'entre chaque tentative.',
          ),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
            child: Text(
              '$number',
              style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

/// Vérification des trois réponses.
class RecoveryVerifyScreen extends StatefulWidget {
  const RecoveryVerifyScreen({super.key, required this.vault});

  final VaultService vault;

  @override
  State<RecoveryVerifyScreen> createState() => _RecoveryVerifyScreenState();
}

class _RecoveryVerifyScreenState extends State<RecoveryVerifyScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _answers = RecoveryQuestionsForm.createControllers();
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  bool _busy = false;
  String? _error;
  bool _unavailable = false;
  Duration _wait = Duration.zero;
  DateTime? _waitUntil;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    widget.vault.recoveryWait().then(_startWait);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _shake.dispose();
    for (final c in _answers) {
      c.dispose();
    }
    super.dispose();
  }

  void _startWait(Duration wait) {
    if (!mounted) return;
    _ticker?.cancel();
    _waitUntil = DateTime.now().add(wait);
    setState(() => _wait = wait);
    if (wait <= Duration.zero) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = _waitUntil!.difference(DateTime.now());
      setState(() => _wait = left.isNegative ? Duration.zero : left);
      if (left <= Duration.zero) timer.cancel();
    });
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final attempt = await widget.vault.verifyRecovery([for (final c in _answers) c.text]);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (attempt.outcome) {
      case RecoveryOutcome.allowed:
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => NewMasterPasswordScreen(vault: widget.vault, session: attempt.session!),
          ),
        );
      case RecoveryOutcome.refused:
        setState(() {
          _error =
              'Ces réponses ne permettent pas d\'ouvrir le coffre. Vérifiez-les et '
              'réessayez.';
        });
        if (!MediaQuery.disableAnimationsOf(context)) _shake.forward(from: 0);
        _startWait(attempt.wait);
      case RecoveryOutcome.throttled:
        _startWait(attempt.wait);
      case RecoveryOutcome.cancelled:
        setState(
          () => _error =
              'Confirmation par le téléphone annulée. Elle est nécessaire '
              'pour vérifier vos réponses.',
        );
      case RecoveryOutcome.unavailable:
        setState(() {
          _unavailable = true;
          _error =
              'La récupération n\'est plus possible sur ce téléphone : son verrouillage '
              'd\'écran a été modifié ou supprimé. Seul le mot de passe maître peut ouvrir '
              'le coffre.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waiting = _wait > Duration.zero;
    return _FlowPage(
      title: 'Questions de récupération',
      bottom: FilledButton(
        onPressed: _busy || waiting || _unavailable ? null : _verify,
        child: _busy
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: theme.colorScheme.primary,
                ),
              )
            : Text(waiting ? 'Prochain essai dans ${formatWait(_wait)}' : 'Vérifier mes réponses'),
      ),
      children: [
        const SizedBox(height: 8),
        Text('Répondez aux trois questions', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Saisissez les réponses données lors de la configuration. Majuscules, accents et '
          'espaces en trop ne comptent pas.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(sin(_shake.value * pi * 5) * 10 * (1 - _shake.value), 0),
            child: child,
          ),
          child: Form(
            key: _formKey,
            child: RecoveryQuestionsForm(
              controllers: _answers,
              enabled: !_busy && !_unavailable,
              onSubmitted: _verify,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 20),
          Notice(key: const Key('recoveryError'), text: _error!, tone: NoticeTone.error),
        ],
        if (waiting) ...[
          const SizedBox(height: 12),
          Notice(
            icon: Icons.timer_outlined,
            text: 'Trop de tentatives. Patientez ${formatWait(_wait)} avant de réessayer.',
          ),
        ],
      ],
    );
  }
}

/// Choix du nouveau mot de passe maître, après des réponses correctes.
class NewMasterPasswordScreen extends StatefulWidget {
  const NewMasterPasswordScreen({super.key, required this.vault, required this.session});

  final VaultService vault;
  final RecoverySession session;

  @override
  State<NewMasterPasswordScreen> createState() => _NewMasterPasswordScreenState();
}

class _NewMasterPasswordScreenState extends State<NewMasterPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.vault.completeRecovery(widget.session, _password.text);
    } on StateError {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Vérification expirée'),
          content: const Text(
            'Pour votre sécurité, l\'autorisation ne dure que quelques minutes et ne sert '
            'qu\'une fois. Répondez de nouveau aux questions.',
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => Navigator.pop(context),
              child: const Text('Recommencer'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
      return;
    }
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RecoverySuccessScreen(entryCount: widget.vault.entries.length),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const min = VaultService.minMasterPasswordLength;
    return _FlowPage(
      title: 'Nouveau mot de passe',
      bottom: FilledButton(
        onPressed: _busy ? null : _save,
        child: _busy
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.primary),
              )
            : const Text('Enregistrer et ouvrir le coffre'),
      ),
      children: [
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.centerLeft,
          child: ShieldAvatar.icon(Icons.verified_user_rounded, size: 52),
        ),
        const SizedBox(height: 20),
        Text('Réponses vérifiées', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Choisissez votre nouveau mot de passe maître. L\'ancien ne fonctionnera plus ; vos '
          'identifiants, vos réponses et le déverrouillage par empreinte sont conservés.',
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('newMasterPassword'),
                controller: _password,
                obscureText: _obscure,
                enabled: !_busy,
                autofocus: true,
                style: const TextStyle(fontSize: 17),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe maître',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Afficher' : 'Masquer',
                    icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v ?? '').length < min ? 'Au moins $min caractères' : null,
              ),
              const SizedBox(height: 12),
              StrengthMeter(password: _password.text),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('confirmNewMasterPassword'),
                controller: _confirm,
                obscureText: _obscure,
                enabled: !_busy,
                style: const TextStyle(fontSize: 17),
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Confirmez le mot de passe',
                  prefixIcon: Icon(Icons.lock_reset_rounded),
                ),
                validator: (v) =>
                    v != _password.text ? 'Les deux mots de passe sont différents' : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Confirmation : le coffre est ouvert avec le nouveau mot de passe.
class RecoverySuccessScreen extends StatelessWidget {
  const RecoverySuccessScreen({super.key, required this.entryCount});

  final int entryCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final animate = !MediaQuery.disableAnimationsOf(context);
    final kept = switch (entryCount) {
      0 => 'Votre coffre est prêt.',
      1 => 'Votre identifiant est intact.',
      final n => 'Vos $n identifiants sont intacts.',
    };
    return _FlowPage(
      title: 'Accès rétabli',
      canPop: false,
      bottom: FilledButton(
        onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
        child: const Text('Ouvrir mon coffre'),
      ),
      children: [
        const SizedBox(height: 48),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: animate ? 0.6 : 1, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: const ShieldAvatar.icon(Icons.check_rounded, size: 96),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Nouveau mot de passe enregistré',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Text(
          '$kept Utilisez désormais votre nouveau mot de passe maître pour ouvrir le coffre.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
