import 'package:flutter/material.dart';

import '../models/classification_result.dart';
import '../theme/design_tokens.dart';
import '../widgets/primary_button.dart';
import '../widgets/result_card.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    required this.result,
    required this.onScanAgain,
    super.key,
  });

  final ClassificationResult result;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ResultCard(result: result),
            const SizedBox(height: DesignTokens.spacingLarge),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                icon: Icons.camera_alt,
                label: 'Scan Again',
                onPressed: onScanAgain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
