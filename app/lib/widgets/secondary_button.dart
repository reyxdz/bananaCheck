import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// A supporting action that sits beside or below a [PrimaryButton]:
/// outlined, same height and shape, never competing for attention.
/// Always icon + label (§7.2), at least 48dp tall (§7.4).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
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
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: DesignTokens.iconAppBar),
        label: Text(label),
      ),
    );
  }
}
