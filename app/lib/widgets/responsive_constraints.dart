import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Caps its child at [DesignTokens.contentMaxWidth] and centres it on
/// wide screens (tablets/desktop); passes it through untouched below
/// that width, so phones keep their edge-to-edge layout.
class ContentWidthBox extends StatelessWidget {
  const ContentWidthBox({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= DesignTokens.contentMaxWidth) {
          return child;
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: DesignTokens.contentMaxWidth,
            ),
            child: child,
          ),
        );
      },
    );
  }
}
