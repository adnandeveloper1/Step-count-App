// The one place steps become distance and calories, so every screen, the
// home widget and the cloud sync show the same numbers.
class CalorieCalculator {
  // Average walking stride is about 41.3% of height.
  static double strideMeters(double heightCm) => heightCm * 0.413 / 100;

  static double distanceKm(int steps, double heightCm) =>
      steps * strideMeters(heightCm) / 1000;

  // Walking burns about 1.036 kcal per kg of body weight per km.
  static double calories(
    int steps, {
    required double heightCm,
    required double weightKg,
  }) => distanceKm(steps, heightCm) * weightKg * 1.036;
}
