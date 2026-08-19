import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../widgets/primary_button.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({
    required this.onScan,
    required this.onHistory,
    super.key,
  });

  final VoidCallback onScan;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacingLarge),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Banana Check',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton.icon(
                    onPressed: onHistory,
                    icon: const Icon(Icons.history),
                    label: const Text('History'),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spacingMedium),
              const Expanded(child: _FieldOfViewFrame()),
              const SizedBox(height: DesignTokens.spacingLarge),
              SizedBox(
                width: double.infinity,
                height: DesignTokens.primaryActionSize,
                child: PrimaryButton(
                  icon: Icons.camera_alt,
                  label: 'Scan',
                  onPressed: onScan,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldOfViewFrame extends StatelessWidget {
  const _FieldOfViewFrame();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        border: Border.all(
          color: DesignTokens.border,
          width: DesignTokens.borderWidth,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        boxShadow: const [
          BoxShadow(
            color: DesignTokens.shadow,
            blurRadius: DesignTokens.spacingMedium,
            offset: Offset(
              DesignTokens.spacingExtraSmall,
              DesignTokens.spacingSmall,
            ),
          ),
        ],
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(DesignTokens.spacingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.center_focus_strong,
                color: DesignTokens.primary,
                size: DesignTokens.iconLarge,
              ),
              SizedBox(height: DesignTokens.spacingMedium),
              Text(
                'Point at a banana and tap Scan.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: DesignTokens.spacingSmall),
              Text(
                'Camera view will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DesignTokens.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
