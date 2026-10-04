import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Shared top bar for the app's screens.
///
/// * [ScreenHeader.brand] — logo + "Bananalyze" wordmark, for the home
///   (camera) screen.
/// * Default constructor — optional back button + screen title.
///
/// [actions] sit on the right (e.g. History, Clear all).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    required String this.title,
    this.onBack,
    this.backTooltip = 'Go back',
    this.actions = const [],
    super.key,
  }) : showBrand = false;

  const ScreenHeader.brand({
    this.actions = const [],
    super.key,
  })  : title = null,
        onBack = null,
        backTooltip = 'Go back',
        showBrand = true;

  final String? title;

  /// Shows a back arrow when set.
  final VoidCallback? onBack;
  final String backTooltip;
  final List<Widget> actions;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingMedium,
        DesignTokens.spacingSmall,
        DesignTokens.spacingSmall,
        DesignTokens.spacingSmall,
      ),
      child: SizedBox(
        height: DesignTokens.minimumTouchTarget,
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                onPressed: onBack,
                tooltip: backTooltip,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            if (showBrand) ...[
              const SizedBox(width: DesignTokens.spacingSmall),
              const BrandMark(),
            ] else ...[
              SizedBox(
                width: onBack == null
                    ? DesignTokens.spacingSmall
                    : DesignTokens.spacingExtraSmall,
              ),
              Expanded(
                child: Text(
                  title!,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
            if (showBrand) const Spacer(),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// Logo tile + "Bananalyze" wordmark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusXSmall),
          child: Image.asset(
            'assets/images/logo.png',
            width: DesignTokens.logoSmall,
            height: DesignTokens.logoSmall,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.eco_rounded,
              color: DesignTokens.primary,
              size: DesignTokens.logoSmall,
            ),
          ),
        ),
        const SizedBox(width: DesignTokens.spacingSmall + 2),
        const Text(
          'Bananalyze',
          style: TextStyle(
            fontSize: DesignTokens.titleTextSize,
            fontWeight: FontWeight.w700,
            color: DesignTokens.primaryDark,
            letterSpacing: DesignTokens.headingLetterSpacing,
          ),
        ),
      ],
    );
  }
}
