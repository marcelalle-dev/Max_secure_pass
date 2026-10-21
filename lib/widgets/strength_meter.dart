import 'package:flutter/material.dart';

import '../services/password_generator.dart';

/// Barre colorée indiquant la robustesse d'un mot de passe.
class StrengthMeter extends StatelessWidget {
  const StrengthMeter({super.key, required this.password});

  final String password;

  static const _colors = {
    PasswordStrength.veryWeak: Colors.red,
    PasswordStrength.weak: Colors.deepOrange,
    PasswordStrength.medium: Colors.amber,
    PasswordStrength.strong: Colors.lightGreen,
    PasswordStrength.veryStrong: Colors.green,
  };

  @override
  Widget build(BuildContext context) {
    final strength = passwordStrength(password);
    final color = _colors[strength]!;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (strength.index + 1) / PasswordStrength.values.length,
              color: color,
              backgroundColor: color.withValues(alpha: 0.2),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          strength.label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
