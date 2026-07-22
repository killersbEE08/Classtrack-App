package com.classtrack.classtrack

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget showing today's ClassTrack snapshot. Data is pushed from
 * Dart via the home_widget plugin (see HomeWidgetService). Tapping opens the app.
 */
class ClassTrackWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.classtrack_widget).apply {
                setTextViewText(
                    R.id.widget_title,
                    widgetData.getString("title", "ClassTrack")
                )
                setTextViewText(
                    R.id.widget_line1,
                    widgetData.getString("line1", "Open to see today")
                )
                setTextViewText(
                    R.id.widget_line2,
                    widgetData.getString("line2", "")
                )

                val launchIntent = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        0,
                        launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
