package com.example.habit_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class EagleWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                
                // 1. Update Streak
                val streak = widgetData.getString("streak", "0") ?: "0"
                setTextViewText(R.id.streak_value, streak)

                // 2. Update Dots
                // Expecting a csv string: "1,0,1,1,1,0,0" (1=filled, 0=empty)
                val history = widgetData.getString("history_7", "0,0,0,0,0,0,0") ?: "0,0,0,0,0,0,0"
                val days = history.split(",")
                
                // Map dot IDs
                val dotIds = listOf(
                    R.id.dot1, R.id.dot2, R.id.dot3, R.id.dot4, R.id.dot5, R.id.dot6, R.id.dot7
                )

                // Loop through last 7 days (or however many we have)
                for (i in 0 until 7) {
                    if (i < days.size) {
                        val isFilled = days[i] == "1"
                        setImageViewResource(
                            dotIds[i], 
                            if (isFilled) R.drawable.dot_filled else R.drawable.dot_empty
                        )
                    }
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
