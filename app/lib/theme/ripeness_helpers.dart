import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Centralised ripeness → color / icon lookup.
///
/// Eliminates the duplicated switch-cases that were scattered across
/// [ResultCard] and [_HistoryCard]. Every widget that needs a ripeness
/// color or icon should call these helpers instead of re-implementing
/// the mapping.
abstract final class RipenessHelpers {
  /// Returns the brand color associated with [ripeness].
  static Color colorFor(String ripeness) {
    switch (ripeness.toLowerCase()) {
      case 'unripe':
        return DesignTokens.ripenessUnripe;
      case 'ripe':
        return DesignTokens.ripenessRipe;
      case 'overripe':
        return DesignTokens.ripenessOverripe;
      default:
        return DesignTokens.primary;
    }
  }

  /// Returns the icon associated with [ripeness].
  static IconData iconFor(String ripeness) {
    switch (ripeness.toLowerCase()) {
      case 'unripe':
        return Icons.hourglass_top_rounded;
      case 'ripe':
        return Icons.check_circle_rounded;
      case 'overripe':
        return Icons.warning_rounded;
      default:
        return Icons.eco_rounded;
    }
  }
}
