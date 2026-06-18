package com.ravehub.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import com.example.ravehub.R
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit

class RaverCountdownWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // Called when the first widget is created
    }

    override fun onDisabled(context: Context) {
        // Called when the last widget is removed
    }

    companion object {
        private const val PREFS_NAME = "ravehub_widget_prefs"
        private const val KEY_EVENT_ID = "upcoming_event_id"
        private const val KEY_EVENT_NAME = "upcoming_event_name"
        private const val KEY_EVENT_DATE = "upcoming_event_date"
        private const val KEY_EVENT_VENUE = "upcoming_event_venue"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            val eventId = prefs.getString(KEY_EVENT_ID, null)
            val eventName = prefs.getString(KEY_EVENT_NAME, null)
            val eventDateStr = prefs.getString(KEY_EVENT_DATE, null)
            val venueName = prefs.getString(KEY_EVENT_VENUE, null)

            val views = RemoteViews(context.packageName, R.layout.raver_countdown_widget)

            if (eventId.isNullOrEmpty() || eventName.isNullOrEmpty() || eventDateStr.isNullOrEmpty()) {
                // No event data available
                views.setTextViewText(R.id.widget_event_name, "No upcoming events")
                views.setTextViewText(R.id.widget_days_text, "--")
                views.setTextViewText(R.id.widget_brand_text, "RAVEHUB")
            } else {
                val daysUntil = calculateDaysUntil(eventDateStr)

                views.setTextViewText(R.id.widget_event_name, eventName)
                views.setTextViewText(
                    R.id.widget_days_text,
                    if (daysUntil >= 0) "${daysUntil}d" else "LIVE"
                )
                views.setTextViewText(R.id.widget_brand_text, "RAVEHUB")

                // Set up deep link tap intent
                val deepLinkUri = Uri.parse("raver://event/$eventId")
                val intent = Intent(Intent.ACTION_VIEW, deepLinkUri).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    appWidgetId,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_event_name, pendingIntent)
                views.setOnClickPendingIntent(R.id.widget_days_text, pendingIntent)
                views.setOnClickPendingIntent(R.id.widget_brand_text, pendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun calculateDaysUntil(dateString: String): Long {
            return try {
                val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                    timeZone = TimeZone.getTimeZone("UTC")
                }
                val eventDate = format.parse(dateString)
                    ?: SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
                        timeZone = TimeZone.getTimeZone("UTC")
                    }.parse(dateString)
                    ?: return -1

                val now = Date()
                val diffMs = eventDate.time - now.time
                if (diffMs < 0) -1 else TimeUnit.MILLISECONDS.toDays(diffMs)
            } catch (e: Exception) {
                -1
            }
        }
    }
}
