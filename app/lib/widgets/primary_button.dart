import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// The one main action on a screen: filled botanical green, icon + label
/// (§7.2), at least 48dp tall (§7.4). Styling comes from the app theme.
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
