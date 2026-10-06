import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/ripeness_helpers.dart';
import '../widgets/screen_header.dart';
import '../widgets/section_container.dart';

/// About Bananalyze: what the app does, how to use it, what it can
/// recognise, and how it treats the user's photos. Opened by tapping the
/// logo on the home (camera) screen.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// Keep in step with `version:` in pubspec.yaml.
  static const appVersion = '1.0.0';

  /// Varieties the model recognises, by the names shown to users.
  static const varieties = [
    'Cavendish',
    'Cardaba',
    'Lakatan',
    'Latundan',
    'Saba',
    'Señorita',
  ];

  static const _ripenessStages = ['Unripe', 'Ripe', 'Overripe'];

  static const _steps = [
    'Hold one banana inside the frame on the camera screen.',
    'Tap Scan, or upload a photo from your gallery.',
    'Read the variety, ripeness, handling tip and serving ideas.',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const gap = SizedBox(height: DesignTokens.spacingSmall + 4);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'About',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DesignTokens.spacingMedium,
                  DesignTokens.spacingSmall,
                  DesignTokens.spacingMedium,
                  DesignTokens.spacingExtraLarge,
                ),
                children: [
                  const _Hero(version: appVersion),
                  const SizedBox(height: DesignTokens.spacingLarge),
                  SectionContainer(
                    title: 'What it does',
                    icon: Icons.center_focus_strong_rounded,
                    child: Text(
                      'Bananalyze looks at a photo of a banana and tells you '
                      'its variety and how ripe it is. It is made for '
                      'farmers, vendors and anyone who buys bananas.',
                      style: textTheme.bodyLarge,
                    ),
                  ),
                  gap,
                  SectionContainer(
                    title: 'How to use it',
                    icon: Icons.photo_camera_outlined,
                    child: Column(
                      children: [
                        for (var i = 0; i < _steps.length; i++)
                          _Step(number: i + 1, text: _steps[i]),
                      ],
                    ),
                  ),
                  gap,
                  SectionContainer(
                    title: 'Varieties it knows',
                    icon: Icons.eco_rounded,
                    child: Wrap(
                      spacing: DesignTokens.spacingSmall,
                      runSpacing: DesignTokens.spacingSmall,
                      children: [
                        for (final v in varieties) _Chip(label: v),
                      ],
                    ),
                  ),
                  gap,
                  SectionContainer(
                    title: 'Ripeness stages',
                    icon: Icons.timelapse_rounded,
                    child: Column(
                      children: [
                        for (final r in _ripenessStages) _Stage(ripeness: r),
                      ],
                    ),
                  ),
                  gap,
                  SectionContainer(
                    title: 'Private and offline',
                    icon: Icons.lock_outline_rounded,
                    child: Text(
                      'Every scan runs on your phone. No internet is needed, '
                      'and your photos and history never leave the device.',
                      style: textTheme.bodyLarge,
                    ),
                  ),
                  gap,
                  SectionContainer(
                    title: 'A note on accuracy',
                    icon: Icons.info_outline_rounded,
                    iconColor: DesignTokens.warning,
                    background: DesignTokens.accentLight,
                    child: Text(
                      'Results are a best guess from one photo. Good light '
                      'and a single banana in frame give the best answer. '
                      'Check the fruit yourself before selling or eating.',
                      style: textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spacingLarge),
                  Text(
                    'Typeface: Plus Jakarta Sans, SIL Open Font License 1.1',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: DesignTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
          child: Image.asset(
            'assets/images/logo.png',
            width: DesignTokens.aboutLogoSize,
            height: DesignTokens.aboutLogoSize,
            fit: BoxFit.cover,
            semanticLabel: 'Bananalyze logo',
          ),
        ),
        const SizedBox(height: DesignTokens.spacingMedium),
        const Text(
          'Bananalyze',
          style: TextStyle(
            fontSize: DesignTokens.headingTextSize,
            fontWeight: FontWeight.w700,
            color: DesignTokens.primaryDark,
            letterSpacing: DesignTokens.headingLetterSpacing,
          ),
        ),
        const SizedBox(height: DesignTokens.spacingExtraSmall),
        Text(
          'Banana variety and ripeness checker',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: DesignTokens.textSecondary,
              ),
        ),
        const SizedBox(height: DesignTokens.spacingSmall),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.chipPaddingHorizontal,
            vertical: DesignTokens.chipPaddingVertical,
          ),
          decoration: BoxDecoration(
            color: DesignTokens.primaryLight,
            borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
          ),
          child: Text(
            'Version $version',
            style: const TextStyle(
              fontSize: DesignTokens.chipTextSize,
              fontWeight: FontWeight.w700,
              color: DesignTokens.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: DesignTokens.spacingExtraSmall,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: DesignTokens.iconMedium,
            height: DesignTokens.iconMedium,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: DesignTokens.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: DesignTokens.chipTextSize,
                fontWeight: FontWeight.w700,
                color: DesignTokens.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.spacingSmall + 4),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.chipPaddingHorizontal,
        vertical: DesignTokens.chipPaddingVertical,
      ),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        border: Border.all(color: DesignTokens.border),
        borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: DesignTokens.chipTextSize,
          fontWeight: FontWeight.w700,
          color: DesignTokens.textPrimary,
        ),
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.ripeness});

  final String ripeness;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: DesignTokens.spacingExtraSmall,
      ),
      child: Row(
        children: [
          Icon(
            RipenessHelpers.iconFor(ripeness),
            color: RipenessHelpers.colorFor(ripeness),
            size: DesignTokens.iconMedium,
          ),
          const SizedBox(width: DesignTokens.spacingSmall + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ripeness,
                  style: const TextStyle(
                    fontSize: DesignTokens.bodyTextSize,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.textPrimary,
                  ),
                ),
                Text(
                  RipenessHelpers.summaryFor(ripeness),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DesignTokens.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
