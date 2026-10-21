import 'package:flutter/material.dart';

import '../services/password_generator.dart';
import '../theme/app_theme.dart';

/// Jauge de robustesse en cinq segments.
class StrengthMeter extends StatelessWidget {
  const StrengthMeter({super.key, required this.password});

  final String password;

  static Color colorOf(PasswordStrength strength, ColorScheme scheme) => switch (strength) {
    PasswordStrength.veryWeak => scheme.error,
    PasswordStrength.weak => const Color(0xFFE8590C),
    PasswordStrength.medium => const Color(0xFFD99A00),
    PasswordStrength.strong => scheme.primary,
    PasswordStrength.veryStrong =>
      scheme.brightness == Brightness.light ? BrandColors.deep : scheme.secondary,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strength = passwordStrength(password);
    final color = colorOf(strength, scheme);
    return Semantics(
      label: 'Robustesse : ${strength.label}',
      child: Row(
        children: [
          for (var i = 0; i < PasswordStrength.values.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 6,
                decoration: BoxDecoration(
                  color: i <= strength.index ? color : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
          const SizedBox(width: 12),
          SizedBox(
            width: 76,
            child: Text(
              strength.label,
              textAlign: TextAlign.end,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
