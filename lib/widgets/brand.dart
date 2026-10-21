import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Silhouette du bouclier du logo, dans une boîte [size] : épaules
/// arrondies en haut, flancs qui se rejoignent en pointe en bas.
Path shieldPath(Size size, {double shoulder = 0.14, double flank = 0.5}) {
  final w = size.width, h = size.height;
  return Path()
    ..moveTo(w / 2, 0)
    ..lineTo(w * 0.94, h * shoulder * 0.8)
    ..quadraticBezierTo(w, h * shoulder, w, h * (shoulder + 0.06))
    ..lineTo(w, h * flank)
    ..cubicTo(w, h * 0.78, w * 0.72, h * 0.92, w / 2, h)
    ..cubicTo(w * 0.28, h * 0.92, 0, h * 0.78, 0, h * flank)
    ..lineTo(0, h * (shoulder + 0.06))
    ..quadraticBezierTo(0, h * shoulder, w * 0.06, h * shoulder * 0.8)
    ..close();
}

/// Peint le bouclier bicolore du logo, coupé verticalement en son milieu.
class SplitShieldPainter extends CustomPainter {
  const SplitShieldPainter({this.shoulder = 0.14, this.flank = 0.5});

  final double shoulder;
  final double flank;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipPath(shieldPath(size, shoulder: shoulder, flank: flank));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width / 2, size.height),
      Paint()..color = BrandColors.signal,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height),
      Paint()..color = BrandColors.deep,
    );
  }

  @override
  bool shouldRepaint(SplitShieldPainter old) => old.shoulder != shoulder || old.flank != flank;
}

/// Petit bouclier portant l'initiale d'une entrée.
class ShieldAvatar extends StatelessWidget {
  const ShieldAvatar({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final initial = label.isEmpty ? '?' : label.characters.first.toUpperCase();
    return SizedBox(
      width: 40,
      height: 46,
      child: CustomPaint(
        painter: const SplitShieldPainter(),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le logo complet (bouclier et clé).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/mark.png',
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
    semanticLabel: 'Max SecurePass',
  );
}

/// « Max SecurePass », en deux couleurs comme sur le logo.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.fontSize = 20, this.onBrand = false});

  final double fontSize;

  /// Version blanche, pour un fond bleu.
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -fontSize * 0.03,
      height: 1.1,
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: 'Max ',
            style: TextStyle(
              color: onBrand ? Colors.white.withValues(alpha: 0.72) : scheme.primary,
            ),
          ),
          TextSpan(
            text: 'SecurePass',
            style: TextStyle(color: onBrand ? Colors.white : scheme.onSurface),
          ),
        ],
      ),
    );
  }
}
