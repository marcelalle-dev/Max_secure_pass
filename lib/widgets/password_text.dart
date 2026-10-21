import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Mot de passe en police à chasse fixe, chiffres et symboles colorés pour
/// distinguer facilement l/1/I ou O/0 à la recopie.
class PasswordText extends StatelessWidget {
  const PasswordText(this.password, {super.key, this.fontSize = 22});

  final String password;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final symbolColor = scheme.brightness == Brightness.light
        ? const Color(0xFFC2410C)
        : const Color(0xFFFF9F6B);
    return Text.rich(
      TextSpan(
        children: [
          for (final char in password.characters)
            TextSpan(
              text: char,
              style: TextStyle(
                color: RegExp('[0-9]').hasMatch(char)
                    ? scheme.primary
                    : RegExp('[a-zA-Z]').hasMatch(char)
                    ? scheme.onSurface
                    : symbolColor,
              ),
            ),
        ],
      ),
      semanticsLabel: password,
      style: TextStyle(
        fontFamily: AppTheme.monoFamily,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.5,
      ),
    );
  }
}
