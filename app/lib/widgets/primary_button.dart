import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: DesignTokens.minimumTouchTarget,
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
