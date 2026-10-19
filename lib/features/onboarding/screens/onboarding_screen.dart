import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_colors.dart';
import '../../step_tracking/presentation/widgets/glass_step_card.dart';
import '../onboarding_content.dart';
import '../widgets/onboarding_widgets.dart';

/// Onboarding: a swipeable carousel. Each page shows a live preview of the
/// feature on a glass card over a soft lime glow, with dots, Back and Next
/// below. The phone's back gesture also goes to the previous page.
class OnboardingScreen extends ConsumerStatefulWidget {
  final int initialPage;

  const OnboardingScreen({super.key, this.initialPage = 0});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final _controller = PageController(initialPage: widget.initialPage);
  late int _page = widget.initialPage;

  bool get _isLast => _page == onboardingPages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      finishOnboarding(ref);
      return;
    }
    _goTo(_page + 1);
  }

  void _back() {
    if (_page > 0) _goTo(_page - 1);
  }

  void _goTo(int page) {
    if (reduceMotion(context)) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Stack(
          children: [
            // Glow behind the card.
            Positioned(
              top: -120,
              left: -80,
              right: -80,
              child: Container(
                height: 460,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryEmerald.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
                    child: Row(
                      children: [
                        Text(
                          'BUILD UP',
                          style: GoogleFonts.sora(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryEmerald,
                          ),
                        ),
                        const Spacer(),
                        AnimatedOpacity(
                          opacity: _isLast ? 0 : 1,
                          duration: const Duration(milliseconds: 200),
                          child: TextButton(
                            key: const Key('onboarding_skip'),
                            onPressed: _isLast
                                ? null
                                : () => finishOnboarding(ref),
                            child: Text(
                              'Skip',
                              style: GoogleFonts.sora(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: onboardingPages.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) => _CarouselPage(index: i),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < onboardingPages.length; i++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                height: 8,
                                width: i == _page ? 28 : 8,
                                decoration: BoxDecoration(
                                  color: i == _page
                                      ? AppColors.primaryEmerald
                                      : Colors.white24,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            if (_page > 0) ...[
                              SizedBox(
                                width: 56,
                                height: 56,
                                child: OutlinedButton(
                                  key: const Key('onboarding_back'),
                                  onPressed: _back,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                    side: const BorderSide(
                                      color: Colors.white24,
                                    ),
                                    shape: const CircleBorder(),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_rounded,
                                    semanticLabel: 'Back',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: PillButton(
                                key: const Key('onboarding_next'),
                                label: _isLast ? 'Get started' : 'Next',
                                icon: Icons.arrow_forward_rounded,
                                onPressed: _next,
                              ),
                            ),
                          ],
                        ),
                      ],
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

class _CarouselPage extends StatelessWidget {
  final int index;

  const _CarouselPage({required this.index});

  @override
  Widget build(BuildContext context) {
    final page = onboardingPages[index];
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: FeatureIllustration(feature: page.feature),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              MonoLabel(
                '0${index + 1} · ${page.tag}',
                color: AppColors.primaryEmerald,
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${page.title} '),
                    TextSpan(
                      text: page.highlight,
                      style: const TextStyle(color: AppColors.primaryEmerald),
                    ),
                  ],
                ),
                style: GoogleFonts.sora(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                page.body,
                style: GoogleFonts.sora(
                  fontSize: 15,
                  height: 1.55,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
