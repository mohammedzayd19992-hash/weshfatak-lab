package com.uninews.uninews

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.*
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

class NewsAlertWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        val prefs = applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!NotificationManagerCompat.from(applicationContext).areNotificationsEnabled()) return Result.success()
        val base = prefs.getString("url", null) ?: return Result.success()
        val key = prefs.getString("key", null) ?: return Result.success()
        val alerts = JSONArray(prefs.getString("alerts", "[]"))
        var retry = false
        for (i in 0 until alerts.length()) {
            val alert = alerts.getJSONObject(i)
            if (!alert.optBoolean("enabled", true)) continue
            val id = alert.getString("id")
            val filters = alert.getJSONObject("filters")
            val since = alert.getString("since")
            val cursorKey = "cursor.$id.$since"
            var cursor = prefs.getLong(cursorKey, 0)
            try {
                // ID pagination keeps newly inserted rows from shifting offsets.
                // collected_at avoids notifying the archive on first activation.
                var pages = 0
                do {
                    val uri = Uri.parse("$base/rest/v1/news_items").buildUpon()
                        .appendQueryParameter("select", "news_id,body,collected_at,sources(name),news_tags(tags(name,tag_group))")
                        .appendQueryParameter("collected_at", "gte.$since")
                        .appendQueryParameter("news_id", "gt.$cursor")
                        .appendQueryParameter("order", "news_id.asc")
                        .appendQueryParameter("limit", "100").build()
                    val connection = URL(uri.toString()).openConnection() as HttpURLConnection
                    val rows = try {
                        connection.connectTimeout = 15000
                        connection.readTimeout = 20000
                        connection.setRequestProperty("apikey", key)
                        // Public news uses only a publishable key; no account session or service key.
                        if (connection.responseCode !in 200..299) throw java.io.IOException("News API unavailable")
                        JSONArray(connection.inputStream.bufferedReader().use { it.readText() })
                    } finally { connection.disconnect() }
                    for (rowIndex in 0 until rows.length()) {
                        val row = rows.getJSONObject(rowIndex)
                        val newsId = row.getLong("news_id")
                        val audiences = mutableSetOf<String>()
                        val categories = mutableSetOf<String>()
                        val tags = row.optJSONArray("news_tags") ?: JSONArray()
                        for (tagIndex in 0 until tags.length()) {
                            val tag = tags.getJSONObject(tagIndex).optJSONObject("tags") ?: continue
                            when (tag.optString("tag_group")) {
                                "audience" -> audiences.add(tag.getString("name"))
                                "category" -> categories.add(tag.getString("name"))
                            }
                        }
                        // A removed or paused filter must stop delivery even during a network request.
                        val latest = JSONArray(prefs.getString("alerts", "[]"))
                        val stillEnabled = (0 until latest.length()).any { n ->
                            val current = latest.getJSONObject(n)
                            current.optString("id") == id && current.optString("since") == since && current.optBoolean("enabled", true)
                        }
                        if (!stillEnabled) break
                        if (AlertRules.matches(audiences, categories,
                            strings(filters.optJSONArray("audiences")), strings(filters.optJSONArray("categories")),
                            alert.optBoolean("importantOnly", true))) {
                            // Overlapping saved filters deliver each story once.
                            if (!prefs.getBoolean("delivered.$newsId", false)) {
                                showNotification(newsId, row.getString("body"), row.getJSONObject("sources").getString("name"))
                                prefs.edit().putBoolean("delivered.$newsId", true).commit()
                            }
                        }
                        cursor = newsId
                        prefs.edit().putLong(cursorKey, cursor).commit()
                    }
                    pages++
                } while (rows.length() == 100 && pages < 5 && !isStopped)
            } catch (_: Exception) { retry = true }
        }
        return if (retry) Result.retry() else Result.success()
    }

    private fun showNotification(id: Long, body: String, source: String) {
        val context = applicationContext
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val arabic = if (Build.VERSION.SDK_INT >= 24) context.resources.configuration.locales[0].language == "ar"
            else @Suppress("DEPRECATION") (context.resources.configuration.locale.language == "ar")
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(
            CHANNEL, if (arabic) "أخبار الفلاتر المحفوظة" else "Saved filter news", NotificationManager.IMPORTANCE_DEFAULT))
        val intent = Intent(context, MainActivity::class.java)
            .setAction("news.$id").putExtra("news_id", id)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pending = PendingIntent.getActivity(context, id.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_news_notification)
            .setContentTitle(if (arabic) "وش فاتك · $source" else "WeshFatak · $source")
            .setContentText(body.lineSequence().first().take(180))
            .setStyle(NotificationCompat.BigTextStyle().bigText(body.take(1500)))
            .setContentIntent(pending).setAutoCancel(true).setOnlyAlertOnce(true).build()
        manager.notify("news", id.hashCode(), notification)
    }

    companion object {
        const val PREFS = "weshfatak_news_alerts"
        const val CHANNEL = "saved_filter_news"
        private const val WORK = "weshfatak_news_checks"
        fun strings(array: JSONArray?): Set<String> = if (array == null) emptySet()
            else (0 until array.length()).map { array.getString(it) }.toSet()
        fun schedule(context: Context, enabled: Boolean) {
            val manager = WorkManager.getInstance(context)
            if (!enabled) { manager.cancelUniqueWork(WORK); return }
            val constraints = Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
            val request = PeriodicWorkRequestBuilder<NewsAlertWorker>(15, TimeUnit.MINUTES)
                .setConstraints(constraints).build()
            manager.enqueueUniquePeriodicWork(WORK, ExistingPeriodicWorkPolicy.KEEP, request)
        }
    }
}
