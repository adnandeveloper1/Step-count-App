import 'package:build_up/core/utils/calorie_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stride is 41.3% of height', () {
    expect(CalorieCalculator.strideMeters(170), closeTo(0.7021, 1e-9));
  });

  test('distance comes from steps and stride', () {
    expect(CalorieCalculator.distanceKm(1000, 170), closeTo(0.7021, 1e-9));
  });

  test('calories use height and weight, not a flat rate per step', () {
    expect(
      CalorieCalculator.calories(1000, heightCm: 170, weightKg: 70),
      closeTo(50.916, 0.001),
    );
    // A heavier person burns more for the same steps.
    expect(
      CalorieCalculator.calories(1000, heightCm: 170, weightKg: 90),
      greaterThan(
        CalorieCalculator.calories(1000, heightCm: 170, weightKg: 70),
      ),
    );
  });

  test('no steps, no calories', () {
    expect(CalorieCalculator.calories(0, heightCm: 170, weightKg: 70), 0);
  });
}
