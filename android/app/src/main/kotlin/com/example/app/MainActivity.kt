package com.example.app

import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "consistiq/study_mode"
    private var pendingRingtoneResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "hasOverlay" -> result.success(Settings.canDrawOverlays(this))
                    "hasDnd" -> result.success(
                        getSystemService(NotificationManager::class.java)
                            .isNotificationPolicyAccessGranted
                    )
                    "openUsageAccess" -> openSettings(
                        Settings.ACTION_USAGE_ACCESS_SETTINGS,
                        "package:$packageName",
                        result
                    )
                    "openOverlay" -> openSettings(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        "package:$packageName",
                        result
                    )
                    "openDnd" -> openSettings(
                        Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS,
                        null,
                        result
                    )
                    "installedApps" -> result.success(installedApps())
                    "start" -> {
                        val allowed = call.argument<List<String>>("allowed")
                            ?: emptyList()
                        val end = call.argument<Number>("end")?.toLong() ?: 0L
                        val silent = call.argument<Boolean>("silent") ?: false
                        if (!hasUsageAccess() || !Settings.canDrawOverlays(this)) {
                            result.error(
                                "permissions_denied",
                                "Allow Usage access and Display over other apps before starting Study Mode.",
                                null
                            )
                        } else {
                            StudyBlockService.start(this, allowed, end, silent)
                            result.success(null)
                        }
                        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "consistiq/alarms")
                        .setMethodCallHandler { call, result ->
                            if (call.method == "pickAlarmSound") {
                                pickAlarmSound(call.argument<String>("currentUri"), result)
                            } else {
                                result.notImplemented()
                            }
                        }
                    }

                    @Suppress("DEPRECATION")
                    private fun pickAlarmSound(currentUri: String?, result: MethodChannel.Result) {
                        if (pendingRingtoneResult != null) {
                        result.error("picker_in_progress", "A ringtone picker is already open.", null)
                        return
                        }
                        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                        putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Choose alarm ringtone")
                        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                        if (!currentUri.isNullOrEmpty()) {
                            putExtra(
                                RingtoneManager.EXTRA_RINGTONE_EXISTING_URI,
                                Uri.parse(currentUri)
                            )
                        }
                        }
                        pendingRingtoneResult = result
                        try {
                        startActivityForResult(intent, RINGTONE_REQUEST)
                        } catch (e: Exception) {
                        pendingRingtoneResult = null
                        result.error("ringtone_picker_unavailable", "Could not open ringtone settings.", e.message)
                        }
                    }

                    @Deprecated("Deprecated in Android")
                    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
                        super.onActivityResult(requestCode, resultCode, data)
                        if (requestCode != RINGTONE_REQUEST) return
                        val result = pendingRingtoneResult ?: return
                        pendingRingtoneResult = null
                        if (resultCode != RESULT_OK) {
                        result.success(null)
                        return
                        }
                        val uri = data?.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
                        if (uri != null) {
                        try {
                            contentResolver.takePersistableUriPermission(
                                uri,
                                Intent.FLAG_GRANT_READ_URI_PERMISSION
                            )
                        } catch (_: SecurityException) {
                            // Some ringtone providers grant temporary rather than persistable access.
                        }
                        }
                        result.success(uri?.toString() ?: "")
                    }
                    "stop" -> {
                        StudyBlockService.stop(this)
                        result.success(null)
                    }
                    "status" -> {
                        val prefs = getSharedPreferences(
                            StudyBlockService.PREFS,
                            Context.MODE_PRIVATE
                        )
                        result.success(
                            mapOf(
                                "active" to prefs.getBoolean(
                                    StudyBlockService.KEY_ACTIVE,
                                    false
                                ),
                                "end" to prefs.getLong(
                                    StudyBlockService.KEY_END,
                                    0L
                                )
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName
        ) == AppOpsManager.MODE_ALLOWED
    }

    private fun openSettings(action: String, data: String?, result: MethodChannel.Result) {
        try {
            val intent = Intent(action).apply {
                if (data != null) this.data = Uri.parse(data)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("settings_unavailable", "Could not open Android settings.", e.message)
        }
    }

    private fun installedApps(): List<Map<String, String>> {
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        @Suppress("DEPRECATION")
        return packageManager.queryIntentActivities(launcher, 0)
            .mapNotNull { resolveInfo ->
                val app = resolveInfo.activityInfo?.applicationInfo ?: return@mapNotNull null
                mapOf(
                    "pkg" to app.packageName,
                    "label" to resolveInfo.loadLabel(packageManager).toString()
                )
            }
            .distinctBy { it["pkg"] }
            .sortedBy { it["label"]?.lowercase() }
    }

    companion object {
        private const val RINGTONE_REQUEST = 9402
    }
}
