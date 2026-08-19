import 'package:flutter/material.dart';

import '../models/classification_result.dart';
import '../theme/design_tokens.dart';

class ResultCard extends StatelessWidget {
  const ResultCard({required this.result, super.key});

  final ClassificationResult result;

  String get certaintyLabel {
    if (result.confidence >= 0.85) return "We're pretty sure";
    if (result.confidence >= 0.65) return 'This looks likely';
    return 'Try another photo to be sure';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${result.variety} — ${result.ripeness}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: DesignTokens.spacingSmall),
            Text(certaintyLabel),
          ],
        ),
      ),
    );
  }
}
