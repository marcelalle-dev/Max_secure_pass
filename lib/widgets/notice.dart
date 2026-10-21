import 'package:flutter/material.dart';

enum NoticeTone { info, error }

/// Encadré d'information ou d'erreur.
class Notice extends StatelessWidget {
  const Notice({super.key, required this.text, this.tone = NoticeTone.info, this.icon});

  final String text;
  final NoticeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = tone == NoticeTone.error;
    final color = error ? scheme.error : scheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error
            ? scheme.error.withValues(alpha: 0.08)
            : scheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: error ? Border.all(color: scheme.error.withValues(alpha: 0.4)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? (error ? Icons.error_outline_rounded : Icons.lightbulb_outline_rounded),
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
