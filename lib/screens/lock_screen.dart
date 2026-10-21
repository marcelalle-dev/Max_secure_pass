import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/terms_service.dart';
import '../services/vault_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand.dart';
import '../widgets/strength_meter.dart';
import 'about_screen.dart';

/// Création du coffre (premier lancement) ou déverrouillage.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.vault, required this.terms});

  final VaultService vault;
  final TermsService terms;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  bool get _creating => widget.vault.status == VaultStatus.uninitialized;

  bool get _deviceUnlock => !_creating && widget.vault.deviceUnlockEnabled;

  @override
  void initState() {
    super.initState();
    // Au démarrage ou au retour dans l'application, on propose directement
    // l'empreinte ; pas après un verrouillage volontaire.
    if (_deviceUnlock && !widget.vault.lockedByUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlockWithDevice());
    }
  }

  Future<void> _unlockWithDevice() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final outcome = await widget.vault.unlockWithDevice();
    if (!mounted || outcome == DeviceUnlockOutcome.unlocked) return;
    setState(() {
      _busy = false;
      _error = switch (outcome) {
        DeviceUnlockOutcome.failed =>
          'Empreinte ou code indisponible pour le moment. '
              'Saisissez votre mot de passe maître.',
        DeviceUnlockOutcome.disabled =>
          'Le téléphone ne reconnaît plus votre clé, par exemple après un changement du '
              'verrouillage d\'écran. Saisissez votre mot de passe maître, puis réactivez '
              'l\'empreinte depuis le menu.',
        _ => null,
      };
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else if (!_intro.isAnimating && _intro.value == 0) {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _shake.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    if (_creating) {
      await widget.vault.create(_password.text);
    } else if (!await widget.vault.unlock(_password.text)) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Mot de passe incorrect. Vérifiez les majuscules et réessayez.';
      });
      _password.clear();
      if (!MediaQuery.disableAnimationsOf(context)) _shake.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final headerHeight = (size.height * (_creating ? 0.36 : 0.46)).clamp(240.0, 420.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ShieldHeader(height: headerHeight, intro: _intro),
              SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Form(key: _formKey, child: _form(theme)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(ThemeData theme) {
    final scheme = theme.colorScheme;
    final passwordField = TextFormField(
      key: const Key('masterPassword'),
      controller: _password,
      obscureText: _obscure,
      autofocus: !_creating && !_deviceUnlock,
      enabled: !_busy,
      style: const TextStyle(fontSize: 17),
      decoration: InputDecoration(
        labelText: 'Mot de passe maître',
        errorText: _error,
        errorMaxLines: 2,
        prefixIcon: const Icon(Icons.lock_rounded),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Afficher' : 'Masquer',
          icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      onChanged: _creating ? (_) => setState(() {}) : null,
      onFieldSubmitted: _creating ? null : (_) => _submit(),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Saisissez votre mot de passe maître';
        if (_creating && value.length < VaultService.minMasterPasswordLength) {
          return 'Au moins ${VaultService.minMasterPasswordLength} caractères';
        }
        return null;
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _creating ? 'Créez votre coffre' : 'Déverrouillez votre coffre',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          _creating
              ? 'Ce mot de passe maître chiffre tous vos identifiants. Il ne peut pas '
                    'être récupéré en cas d\'oubli : notez-le en lieu sûr.'
              : _deviceUnlock
              ? 'Utilisez votre empreinte, le code du téléphone ou votre mot de passe maître.'
              : 'Saisissez votre mot de passe maître pour accéder à vos identifiants.',
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(sin(_shake.value * pi * 5) * 10 * (1 - _shake.value), 0),
            child: child,
          ),
          child: passwordField,
        ),
        if (_creating) ...[
          const SizedBox(height: 12),
          StrengthMeter(password: _password.text),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('confirmPassword'),
            controller: _confirm,
            obscureText: _obscure,
            enabled: !_busy,
            style: const TextStyle(fontSize: 17),
            decoration: const InputDecoration(
              labelText: 'Confirmez le mot de passe',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
            onFieldSubmitted: (_) => _submit(),
            validator: (value) =>
                value != _password.text ? 'Les deux mots de passe sont différents' : null,
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.primary),
                )
              : Text(_creating ? 'Créer le coffre' : 'Déverrouiller'),
        ),
        if (_deviceUnlock) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _unlockWithDevice,
            icon: const Icon(Icons.fingerprint_rounded, size: 26),
            label: const Text('Empreinte ou code'),
          ),
        ],
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AboutScreen(terms: widget.terms)),
            ),
            child: const Text('À propos'),
          ),
        ),
      ],
    );
  }
}

/// En-tête en forme de bouclier : le haut de l'écran reprend le logo à
/// grande échelle, avec la clé « M » au centre.
class _ShieldHeader extends StatelessWidget {
  const _ShieldHeader({required this.height, required this.intro});

  final double height;
  final Animation<double> intro;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final keyHeight = (height * 0.36).clamp(84.0, 150.0);
    final curve = CurvedAnimation(parent: intro, curve: Curves.easeOutCubic);
    return SizedBox(
      height: height + topInset,
      child: CustomPaint(
        painter: const _HeaderPainter(),
        child: Padding(
          padding: EdgeInsets.only(top: topInset, bottom: height * 0.2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: curve,
                builder: (context, child) => Opacity(
                  opacity: curve.value,
                  child: Transform.translate(
                    offset: Offset(0, -24 * (1 - curve.value)),
                    child: child,
                  ),
                ),
                child: Image.asset(
                  'assets/branding/key.png',
                  height: keyHeight,
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true,
                ),
              ),
              SizedBox(height: height * 0.07),
              const Wordmark(fontSize: 26, onBrand: true),
              const SizedBox(height: 6),
              Text(
                'Your Passwords. Your Security.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderPainter extends CustomPainter {
  const _HeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.66)
      ..cubicTo(w, h * 0.80, w * 0.70, h * 0.92, w / 2, h)
      ..cubicTo(w * 0.30, h * 0.92, 0, h * 0.80, 0, h * 0.66)
      ..close();
    canvas.clipPath(path);
    canvas.drawRect(Rect.fromLTWH(0, 0, w / 2, h), Paint()..color = BrandColors.signal);
    canvas.drawRect(Rect.fromLTWH(w / 2, 0, w / 2, h), Paint()..color = BrandColors.deep);
  }

  @override
  bool shouldRepaint(_HeaderPainter old) => false;
}
