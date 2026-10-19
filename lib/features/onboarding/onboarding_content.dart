/// Which drawn preview a page shows (see `FeatureIllustration`).
enum OnboardingFeature { steps, gps, coins, race, insights }

/// One feature page shown during onboarding.
class OnboardingPage {
  final OnboardingFeature feature;
  final String tag;
  final String title;
  final String highlight;
  final String body;

  const OnboardingPage({
    required this.feature,
    required this.tag,
    required this.title,
    required this.highlight,
    required this.body,
  });
}

const onboardingPages = <OnboardingPage>[
  OnboardingPage(
    feature: OnboardingFeature.steps,
    tag: 'Track',
    title: 'Every step',
    highlight: 'counts.',
    body:
        'Build Up counts your steps in the background, even when the app is closed. Set a daily goal and check it from your home screen.',
  ),
  OnboardingPage(
    feature: OnboardingFeature.gps,
    tag: 'Map',
    title: 'Map your',
    highlight: 'routes.',
    body:
        'Tap Start Route and Build Up draws your walk or run on the map with GPS, showing distance and time as you go. Every route is saved to your Workout History.',
  ),
  OnboardingPage(
    feature: OnboardingFeature.coins,
    tag: 'Earn',
    title: 'Walk more,',
    highlight: 'earn coins.',
    body:
        'Every 100 steps earns you a coin. Spend coins in the Store on themes, and unlock badges as you hit milestones and keep your streak.',
  ),
  OnboardingPage(
    feature: OnboardingFeature.race,
    tag: 'Compete',
    title: 'Race your',
    highlight: 'friends.',
    body:
        'Join the weekly Step Race, take on challenges and climb the leaderboard. Staying active is easier with company.',
  ),
  OnboardingPage(
    feature: OnboardingFeature.insights,
    tag: 'Grow',
    title: 'See your',
    highlight: 'progress.',
    body:
        'Insights turn your steps, distance and calories into clear charts. Get goal reminders and export a PDF report.',
  ),
];
