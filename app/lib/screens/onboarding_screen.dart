import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/design_tokens.dart';

const _page1Image = 'assets/images/page1.png';
const _page2Image = 'assets/images/page2.png';
const _page3Image = 'assets/images/page3.png';

const _pageCount = 3;

/// Space reserved at the top of each page for the overlaid Back / Skip bar.
const _topBarHeight = DesignTokens.primaryActionSize;

/// Swipeable first-launch tutorial (§7.7, A30).
///
/// Purely presentational: [onFinished] fires when the user taps "Skip" or
/// "Get Started". Persisting the first-launch flag and navigating to the
/// camera is the caller's job.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageDuration = Duration(milliseconds: 350);

  final _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _pageCount - 1;

  /// The welcome page sits on a dark photo, so chrome switches to light.
  bool get _onDark => _index == 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decode ahead of time so swiping never shows a blank frame.
    for (final path in [_page1Image, _page2Image, _page3Image]) {
      precacheImage(AssetImage(path), context);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _controller.animateToPage(
      page,
      duration: _pageDuration,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _onDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: DesignTokens.onboardingBackground,
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _index = i),
                    children: const [
                      _WelcomePage(),
                      _HowItWorksPage(),
                      _ReadyPage(),
                    ],
                  ),
                  SafeArea(bottom: false, child: _buildTopBar()),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final color =
        _onDark ? DesignTokens.onboardingOnDark : DesignTokens.primaryDark;

    return SizedBox(
      height: _topBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacingSmall,
        ),
        child: Row(
          children: [
            if (_index > 0)
              TextButton.icon(
                onPressed: () => _goTo(_index - 1),
                style: TextButton.styleFrom(foregroundColor: color),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back'),
              ),
            const Spacer(),
            TextButton(
              onPressed: widget.onFinished,
              style: TextButton.styleFrom(foregroundColor: color),
              child: const Text('Skip'),
            ),
          ],
        ),
      ),
    );
  }

  /// Dots + one full-width button, identical on every page so nothing
  /// jumps while swiping. Its background follows the swipe from the welcome
  /// photo's dark green into cream, so page 1 still reads as full-bleed.
  Widget _buildBottomBar() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final page =
            _controller.hasClients && _controller.position.haveDimensions
                ? _controller.page!
                : _index.toDouble();
        return ColoredBox(
          color: Color.lerp(
            DesignTokens.onboardingScrim,
            DesignTokens.onboardingBackground,
            page.clamp(0.0, 1.0),
          )!,
          child: child,
        );
      },
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DesignTokens.spacingLarge,
            DesignTokens.spacingSmall,
            DesignTokens.spacingLarge,
            DesignTokens.spacingLarge,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DotIndicator(index: _index, onDark: _onDark),
              const SizedBox(height: DesignTokens.spacingMedium),
              SizedBox(
                width: double.infinity,
                height: DesignTokens.onboardingButtonHeight,
                child: FilledButton(
                  onPressed:
                      _isLast ? widget.onFinished : () => _goTo(_index + 1),
                  style: FilledButton.styleFrom(
                    backgroundColor: _onDark
                        ? DesignTokens.onboardingOnDark
                        : DesignTokens.primaryDark,
                    foregroundColor: _onDark
                        ? DesignTokens.primaryDark
                        : DesignTokens.onboardingOnDark,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: DesignTokens.subheadingTextSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: _LabelWithArrow(_isLast ? 'Get Started' : 'Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Page 1 — Welcome
// ═══════════════════════════════════════════════════════════════════════

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          _page1Image,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          excludeFromSemantics: true,
        ),
        // Darkens the lower half so the white copy stays readable on any
        // part of the photo.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.2, 1],
              colors: [
                DesignTokens.onboardingScrim.withAlpha(0),
                DesignTokens.onboardingScrim,
              ],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: const IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      DesignTokens.spacingLarge,
                      DesignTokens.spacingMedium,
                      DesignTokens.spacingLarge,
                      DesignTokens.spacingMedium,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Brand(),
                        Spacer(),
                        _Headline(
                          'Know your bananas.',
                          color: DesignTokens.onboardingOnDark,
                        ),
                        _Headline(
                          'Better decisions for your harvest.',
                          color: DesignTokens.onboardingHighlight,
                        ),
                        SizedBox(height: DesignTokens.spacingMedium),
                        _Body(
                          'Scan a banana to see its variety and ripeness right on '
                          'your phone. No internet needed.',
                          color: DesignTokens.onboardingOnDarkMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
          child: Image.asset(
            'assets/images/logo.png',
            width: DesignTokens.logoSmall,
            height: DesignTokens.logoSmall,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(width: DesignTokens.spacingSmall),
        const Text(
          'Bananalyze',
          style: TextStyle(
            color: DesignTokens.onboardingOnDark,
            fontSize: DesignTokens.subheadingTextSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Page 2 — How it works
// ═══════════════════════════════════════════════════════════════════════

class _HowItWorksPage extends StatelessWidget {
  const _HowItWorksPage();

  @override
  Widget build(BuildContext context) {
    return _FlowPage(
      header: const [
        _Eyebrow('How it works'),
        _Headline('3 easy steps'),
        SizedBox(height: DesignTokens.spacingLarge),
        _Step(
          number: 1,
          title: 'Take a photo',
          description: 'Point your camera at a banana, or upload a photo.',
        ),
        _Step(
          number: 2,
          title: 'We check it for you',
          description: 'Our AI checks the variety and ripeness on your phone.',
        ),
        _Step(
          number: 3,
          title: 'Get your result',
          description: 'See ripeness, health benefits, and dish ideas.',
        ),
      ],
      image: Image.asset(
        _page2Image,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        semanticLabel: 'A hand holding a phone that is scanning a banana',
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.description,
  });

  final int number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spacingMedium),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: DesignTokens.onboardingStepBadgeSize,
            height: DesignTokens.onboardingStepBadgeSize,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: DesignTokens.primaryDark,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: DesignTokens.onboardingOnDark,
                fontSize: DesignTokens.bodyTextSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: DesignTokens.textPrimary,
                    fontSize: DesignTokens.subheadingTextSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: DesignTokens.spacingExtraSmall),
                _Body(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Page 3 — Get started
// ═══════════════════════════════════════════════════════════════════════

class _ReadyPage extends StatelessWidget {
  const _ReadyPage();

  @override
  Widget build(BuildContext context) {
    return const _FlowPage(
      header: [
        _Eyebrow('Ready to go'),
        _Headline('Smarter farming starts with a scan.'),
        SizedBox(height: DesignTokens.spacingSmall),
        _Body(
          'Know the variety and ripeness of your bananas anytime, '
          'anywhere.',
        ),
        SizedBox(height: DesignTokens.spacingMedium),
      ],
      image: _ResultPreview(),
      footer: [
        SizedBox(height: DesignTokens.spacingMedium),
        _Benefit(Icons.agriculture_rounded, 'Know when to harvest or sell'),
        _Benefit(Icons.recycling_rounded, 'Waste fewer bananas'),
        _Benefit(Icons.payments_outlined, 'Get the right price'),
        SizedBox(height: DesignTokens.spacingSmall),
        Wrap(
          spacing: DesignTokens.spacingMedium,
          children: [
            _FooterNote(Icons.wifi_off_rounded, 'Works offline'),
            _FooterNote(Icons.storefront_rounded, 'For farmers and vendors'),
          ],
        ),
      ],
    );
  }
}

/// The page 3 bananas on a green panel, with a sample result beside them.
class _ResultPreview extends StatelessWidget {
  const _ResultPreview();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: DesignTokens.spacingLarge,
          bottom: 0,
          right: DesignTokens.spacingExtraLarge,
          child: Container(
            decoration: BoxDecoration(
              color: DesignTokens.primaryDark,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            ),
          ),
        ),
        Positioned.fill(
          top: DesignTokens.spacingSmall,
          right: DesignTokens.spacingExtraLarge * 2,
          child: Image.asset(
            _page3Image,
            fit: BoxFit.contain,
            semanticLabel: 'A bunch of ripe bananas',
          ),
        ),
        const Positioned(
          top: 0,
          right: 0,
          child: _SampleResultCard(),
        ),
      ],
    );
  }
}

class _SampleResultCard extends StatelessWidget {
  const _SampleResultCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacingMedium,
        vertical: DesignTokens.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        border: Border.all(
          color: DesignTokens.border,
          width: DesignTokens.sectionBorderWidth,
        ),
        boxShadow: const [
          BoxShadow(
            color: DesignTokens.shadow,
            blurRadius: DesignTokens.spacingMedium,
            offset: Offset(0, DesignTokens.spacingExtraSmall),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SampleResultRow(
            icon: Icons.eco_rounded,
            color: DesignTokens.primary,
            title: 'Cavendish',
            label: 'Variety',
          ),
          Divider(height: DesignTokens.spacingMedium),
          _SampleResultRow(
            icon: Icons.wb_sunny_rounded,
            color: DesignTokens.ripenessRipe,
            title: 'Ripe',
            label: 'Ripeness',
          ),
        ],
      ),
    );
  }
}

class _SampleResultRow extends StatelessWidget {
  const _SampleResultRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: DesignTokens.iconMedium),
        const SizedBox(width: DesignTokens.spacingSmall),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: DesignTokens.textPrimary,
                fontSize: DesignTokens.bodyTextSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: DesignTokens.pillTextSize,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: DesignTokens.spacingExtraSmall,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: DesignTokens.primaryDark,
            size: DesignTokens.iconAppBar,
          ),
          const SizedBox(width: DesignTokens.spacingMedium),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: DesignTokens.textPrimary,
                fontSize: DesignTokens.bodyTextSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Shared pieces
// ═══════════════════════════════════════════════════════════════════════

/// Cream page layout: [header] text on top, [image] filling whatever height
/// is left, then optional [footer]. On short screens (or with large system
/// text) the image shrinks to a minimum and the page scrolls instead of
/// overflowing.
class _FlowPage extends StatelessWidget {
  const _FlowPage({
    required this.header,
    required this.image,
    this.footer = const [],
  });

  final List<Widget> header;
  final Widget image;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DesignTokens.spacingLarge,
                  _topBarHeight,
                  DesignTokens.spacingLarge,
                  DesignTokens.spacingMedium,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...header,
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: DesignTokens.onboardingMinImageHeight,
                        ),
                        // Positioned.fill keeps the image's own size out of
                        // the intrinsic-height calculation.
                        child: Stack(
                          children: [Positioned.fill(child: image)],
                        ),
                      ),
                    ),
                    ...footer,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spacingSmall),
      child: Text(
        text,
        style: const TextStyle(
          color: DesignTokens.onboardingAccentText,
          fontSize: DesignTokens.bodyTextSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline(this.text, {this.color = DesignTokens.primaryDark});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: DesignTokens.onboardingHeadlineSize,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.5,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text, {this.color = DesignTokens.textSecondary});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: DesignTokens.bodyTextSize,
        height: 1.4,
      ),
    );
  }
}

class _LabelWithArrow extends StatelessWidget {
  const _LabelWithArrow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    // Scales down instead of overflowing when system text is very large.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: DesignTokens.spacingSmall),
          const Icon(Icons.arrow_forward_rounded),
        ],
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: DesignTokens.iconSmall,
          color: DesignTokens.textSecondary,
        ),
        const SizedBox(width: DesignTokens.spacingExtraSmall),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: DesignTokens.pillTextSize,
            ),
          ),
        ),
      ],
    );
  }
}

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.index, required this.onDark});

  final int index;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final active =
        onDark ? DesignTokens.onboardingOnDark : DesignTokens.primary;
    final inactive =
        onDark ? DesignTokens.onboardingOnDarkMuted : DesignTokens.border;

    return Semantics(
      label: 'Page ${index + 1} of $_pageCount',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _pageCount; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spacingExtraSmall,
              ),
              width: i == index
                  ? DesignTokens.onboardingActiveDotWidth
                  : DesignTokens.onboardingDotSize,
              height: DesignTokens.onboardingDotSize,
              decoration: BoxDecoration(
                color: i == index ? active : inactive,
                borderRadius: BorderRadius.circular(
                  DesignTokens.onboardingDotSize,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
