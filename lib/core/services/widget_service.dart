import 'package:home_widget/home_widget.dart';

class WidgetService {

  Future<void> updateWidgetData({
    required int steps,
    required int goal,
    required double distance,
    required double calories,
  }) async {

    final int percent = goal > 0 ? (steps / goal * 100).toInt() : 0;


    await HomeWidget.saveWidgetData<String>('steps', steps.toString());
    await HomeWidget.saveWidgetData<String>('goal', '/ $goal');
    await HomeWidget.saveWidgetData<String>('percent', '$percent%');
    await HomeWidget.saveWidgetData<String>('distance', '${distance.toStringAsFixed(1)} km');
    await HomeWidget.saveWidgetData<String>('calories', '${calories.toInt()} kcal');


    await HomeWidget.updateWidget(
      name: 'StepWidgetProvider',
      androidName: 'StepWidgetProvider',
      iOSName: 'StepWidgetProvider',
    );
  }
}