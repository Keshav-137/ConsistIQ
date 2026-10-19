package com.example.app

import android.app.AppOpsManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Process
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class StudyBlockService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var allowedPackages = emptySet<String>()
    private var endMillis = 0L
    private var silent = false
    private var previousInterruptionFilter: Int? = null
    private var blockView: LinearLayout? = null
    private var blockedPackage: String? = null
    private lateinit var windowManager: WindowManager

    private val monitor = object : Runnable {
        override fun run() {
            if (endMillis > 0 && System.currentTimeMillis() >= endMillis) {
                stopSelf()
                return
            }
            val foreground = foregroundPackage()
            if (foreground == null ||
                foreground == packageName ||
                foreground in allowedPackages
            ) {
                removeBlockView()
            } else {
                showBlockView(foreground)
            }
            handler.postDelayed(this, CHECK_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        allowedPackages = (intent?.getStringArrayListExtra(EXTRA_ALLOWED)
            ?: prefs.getStringSet(KEY_ALLOWED, emptySet())?.toCollection(ArrayList())
            ?: arrayListOf()).toSet() + packageName
        endMillis = intent?.getLongExtra(EXTRA_END, prefs.getLong(KEY_END, 0L))
            ?: prefs.getLong(KEY_END, 0L)
        silent = intent?.getBooleanExtra(EXTRA_SILENT, false)
            ?: prefs.getBoolean(KEY_SILENT, false)

        prefs.edit()
            .putBoolean(KEY_ACTIVE, true)
            .putLong(KEY_END, endMillis)
            .putBoolean(KEY_SILENT, silent)
            .putStringSet(KEY_ALLOWED, allowedPackages)
            .apply()

        startForegroundCompat()
        enableSilentModeIfAllowed()
        handler.removeCallbacks(monitor)
        handler.post(monitor)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(monitor)
        removeBlockView()
        restoreInterruptionFilter()
        getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ACTIVE, false)
            .putLong(KEY_END, 0L)
            .remove(KEY_PREVIOUS_FILTER)
            .apply()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startForegroundCompat() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Study mode",
                    NotificationManager.IMPORTANCE_LOW
                )
            )
        }
        val openApp = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }.setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("Study mode is on")
            .setContentText("Distractions are blocked until your session ends.")
            .setContentIntent(openApp)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun foregroundPackage(): String? {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        if (appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            ) != AppOpsManager.MODE_ALLOWED
        ) return null

        val usage = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val events = usage.queryEvents(now - EVENT_LOOKBACK_MS, now)
        val event = UsageEvents.Event()
        var latestPackage: String? = null
        var latestTime = 0L
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if ((event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                    event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) &&
                event.timeStamp >= latestTime
            ) {
                latestPackage = event.packageName
                latestTime = event.timeStamp
            }
        }
        return latestPackage
    }

    private fun showBlockView(app: String) {
        if (!Settings.canDrawOverlays(this)) return
        if (blockedPackage == app && blockView != null) return
        removeBlockView()

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
            setBackgroundColor(Color.rgb(15, 23, 42))
        }
        layout.addView(TextView(this).apply {
            text = "Stay focused"
            textSize = 30f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        })
        layout.addView(TextView(this).apply {
            text = "This app is paused during your study session."
            textSize = 17f
            setTextColor(Color.LTGRAY)
            gravity = Gravity.CENTER
            setPadding(0, 20, 0, 28)
        })
        layout.addView(Button(this).apply {
            text = "Return to ConsistIQ"
            setOnClickListener {
                packageManager.getLaunchIntentForPackage(packageName)?.let {
                    it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    startActivity(it)
                }
            }
        })

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
        }
        try {
            windowManager.addView(layout, params)
            blockView = layout
            blockedPackage = app
        } catch (_: WindowManager.BadTokenException) {
            removeBlockView()
        }
    }

    private fun removeBlockView() {
        val view = blockView ?: return
        try {
            windowManager.removeView(view)
        } catch (_: IllegalArgumentException) {
        }
        blockView = null
        blockedPackage = null
    }

    private fun enableSilentModeIfAllowed() {
        if (!silent) return
        val manager = getSystemService(NotificationManager::class.java)
        if (!manager.isNotificationPolicyAccessGranted) return
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.contains(KEY_PREVIOUS_FILTER)) {
            prefs.edit()
                .putInt(KEY_PREVIOUS_FILTER, manager.currentInterruptionFilter)
                .apply()
        }
        previousInterruptionFilter = prefs.getInt(
            KEY_PREVIOUS_FILTER,
            NotificationManager.INTERRUPTION_FILTER_ALL
        )
        manager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
    }

    private fun restoreInterruptionFilter() {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val previous = previousInterruptionFilter
            ?: if (prefs.contains(KEY_PREVIOUS_FILTER)) {
                prefs.getInt(
                    KEY_PREVIOUS_FILTER,
                    NotificationManager.INTERRUPTION_FILTER_ALL
                )
            } else {
                null
            }
        if (previous != null) {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager.isNotificationPolicyAccessGranted) {
                manager.setInterruptionFilter(previous)
            }
        }
    }

    companion object {
        const val PREFS = "consistiq_study_mode"
        const val KEY_ACTIVE = "active"
        const val KEY_END = "end"
        const val KEY_ALLOWED = "allowed"
        const val KEY_SILENT = "silent"
        const val KEY_PREVIOUS_FILTER = "previous_filter"

        private const val CHANNEL_ID = "consistiq_study_mode"
        private const val NOTIFICATION_ID = 9401
        private const val CHECK_INTERVAL_MS = 700L
        private const val EVENT_LOOKBACK_MS = 15_000L
        private const val ACTION_START = "com.example.app.study.START"
        private const val ACTION_STOP = "com.example.app.study.STOP"
        private const val EXTRA_ALLOWED = "allowed"
        private const val EXTRA_END = "end"
        private const val EXTRA_SILENT = "silent"

        fun start(context: Context, allowed: List<String>, end: Long, silent: Boolean) {
            val intent = Intent(context, StudyBlockService::class.java)
                .setAction(ACTION_START)
                .putStringArrayListExtra(EXTRA_ALLOWED, ArrayList(allowed))
                .putExtra(EXTRA_END, end)
                .putExtra(EXTRA_SILENT, silent)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, StudyBlockService::class.java).setAction(ACTION_STOP))
        }
    }
}
