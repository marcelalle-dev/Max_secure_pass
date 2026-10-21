import 'package:flutter/material.dart';

import '../services/recovery_questions.dart';

/// Les trois questions fixes, chacune avec son champ de réponse.
class RecoveryQuestionsForm extends StatelessWidget {
  const RecoveryQuestionsForm({
    super.key,
    required this.controllers,
    this.enabled = true,
    this.onSubmitted,
  });

  final List<TextEditingController> controllers;
  final bool enabled;
  final VoidCallback? onSubmitted;

  static List<TextEditingController> createControllers() => [
    for (final _ in recoveryQuestions) TextEditingController(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < recoveryQuestions.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(recoveryQuestions[i], style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: Key('recoveryAnswer$i'),
            controller: controllers[i],
            enabled: enabled,
            // Pas de suggestions ni d'apprentissage par le clavier.
            keyboardType: TextInputType.visiblePassword,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            textInputAction: i < recoveryQuestions.length - 1
                ? TextInputAction.next
                : TextInputAction.done,
            onFieldSubmitted: i == recoveryQuestions.length - 1 && onSubmitted != null
                ? (_) => onSubmitted!()
                : null,
            decoration: const InputDecoration(hintText: 'Votre réponse'),
            validator: (value) => normalizeAnswer(value ?? '').length < minAnswerLength
                ? 'Répondez à cette question'
                : null,
          ),
        ],
      ],
    );
  }
}
