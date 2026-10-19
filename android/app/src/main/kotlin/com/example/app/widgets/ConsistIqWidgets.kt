package com.example.app.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import com.example.app.MainActivity
import com.example.app.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class QuickAddWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_quick_add)
            val intent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("consistiq://widget/add-task")
            )
            views.setOnClickPendingIntent(R.id.quick_add_button, intent)
            views.setOnClickPendingIntent(R.id.quick_add_title, intent)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class TodayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val titles = try {
            JSONArray(widgetData.getString("today_tasks", "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
        val text = if (titles.length() == 0) {
            "No tasks left today"
        } else {
            (0 until titles.length()).joinToString("\n") { index ->
                "• ${titles.optString(index)}"
            }
        }
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_today)
            views.setTextViewText(R.id.today_list, text)
            views.setOnClickPendingIntent(
                R.id.today_widget,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("consistiq://widget/today")
                )
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class ProgressWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val done = widgetData.getString("today_done", "0")?.toIntOrNull() ?: 0
        val total = widgetData.getString("today_total", "0")?.toIntOrNull() ?: 0
        val percent = if (total == 0) 0 else done * 100 / total
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_progress)
            views.setTextViewText(R.id.progress_text, "$done of $total tasks completed")
            views.setProgressBar(R.id.progress_bar, 100, percent, false)
            views.setOnClickPendingIntent(
                R.id.progress_widget,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("consistiq://widget/today")
                )
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
