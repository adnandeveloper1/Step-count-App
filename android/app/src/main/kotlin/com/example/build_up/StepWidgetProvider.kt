package com.example.build_up

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class StepWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val steps = widgetData.getString("steps", "0")
                val goal = widgetData.getString("goal", "/ 10000")
                val percent = widgetData.getString("percent", "0%")
                val distance = widgetData.getString("distance", "0.0 km")
                val calories = widgetData.getString("calories", "0 kcal")

                setTextViewText(R.id.widget_steps, steps)
                setTextViewText(R.id.widget_goal, goal)
                setTextViewText(R.id.widget_percent, percent)
                setTextViewText(R.id.widget_distance, distance)
                setTextViewText(R.id.widget_calories, calories)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}