package com.uninews.uninews

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "weshfatak/news_alerts")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "sync" -> {
                    val alerts = call.argument<String>("alerts") ?: "[]"
                    getSharedPreferences(NewsAlertWorker.PREFS, Context.MODE_PRIVATE).edit()
                        .putString("url", call.argument<String>("url"))
                        .putString("key", call.argument<String>("key"))
                        .putString("alerts", alerts).commit()
                    val list = JSONArray(alerts)
                    NewsAlertWorker.schedule(this, (0 until list.length()).any { list.getJSONObject(it).optBoolean("enabled", true) })
                    result.success(null)
                }
                "permission" -> result.success(NotificationManagerCompat.from(this).areNotificationsEnabled())
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        if (permissionResult != null) result.error("busy", "Permission request already open", null)
                        else { permissionResult = result; requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 701) }
                    } else result.success(NotificationManagerCompat.from(this).areNotificationsEnabled())
                }
                "launchPost" -> {
                    val id = intent?.getLongExtra("news_id", -1) ?: -1
                    intent?.removeExtra("news_id")
                    result.success(if (id > 0) id else null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 701) {
            permissionResult?.success(NotificationManagerCompat.from(this).areNotificationsEnabled())
            permissionResult = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val id = intent.getLongExtra("news_id", -1)
        if (id > 0) { channel?.invokeMethod("openPost", id); intent.removeExtra("news_id") }
    }
}

