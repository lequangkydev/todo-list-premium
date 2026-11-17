package com.vtn.todolist.reminders

import android.app.Activity
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * What the "Reminder check" screen needs from Android: battery optimisation,
 * the manufacturer's auto-start page, full-screen permission, and showing
 * an alarm-style reminder over the lock screen.
 */
class ReminderChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    init {
        MethodChannel(messenger, "todolist/reminders").setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "info" -> result.success(info())
            "openBatterySettings" -> result.success(openBatterySettings())
            "openAutostart" -> result.success(openAutostart())
            "releaseLockScreen" -> {
                AlarmLaunch.release(activity)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun info(): Map<String, Any> {
        val power = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
        val notifications =
            activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return mapOf(
            "manufacturer" to Build.MANUFACTURER.lowercase(),
            "brand" to Build.BRAND.lowercase(),
            "sdk" to Build.VERSION.SDK_INT,
            "batteryOptimized" to !power.isIgnoringBatteryOptimizations(activity.packageName),
            "fullScreenAllowed" to if (Build.VERSION.SDK_INT >= 34) {
                notifications.canUseFullScreenIntent()
            } else {
                true
            },
        )
    }

    /** The system list of apps under battery optimisation (no special permission) */
    private fun openBatterySettings(): Boolean =
        tryStart(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) ||
            openAppDetails()

    /** The manufacturer's auto-start / background page, else the app's details */
    private fun openAutostart(): Boolean {
        for ((pkg, cls) in AUTOSTART_PAGES) {
            val intent = Intent().setComponent(ComponentName(pkg, cls))
            if (tryStart(intent)) return true
        }
        return openAppDetails()
    }

    private fun openAppDetails(): Boolean = tryStart(
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.fromParts("package", activity.packageName, null)),
    )

    // Package visibility hides other apps' activities from resolveActivity,
    // so just try each one
    private fun tryStart(intent: Intent): Boolean = try {
        activity.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: Exception) {
        false
    }

    companion object {
        private val AUTOSTART_PAGES = listOf(
            // Xiaomi, Redmi, POCO (MIUI / HyperOS)
            "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
            // Huawei, Honor
            "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
            "com.hihonor.systemmanager" to "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            // OPPO, realme, OnePlus (ColorOS)
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
            "com.oneplus.security" to "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
            // vivo, iQOO
            "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
            // ASUS
            "com.asus.mobilemanager" to "com.asus.mobilemanager.autostart.AutoStartActivity",
            // Samsung: battery → background usage limits
            "com.samsung.android.lool" to "com.samsung.android.sm.battery.ui.BatteryActivity",
        )
    }
}

/**
 * An alarm-style reminder opens the app through its full-screen intent; let
 * it show over the lock screen and wake the display for that one screen only,
 * so the app is never left readable on a locked phone.
 */
object AlarmLaunch {
    private const val SELECT_NOTIFICATION = "SELECT_NOTIFICATION"

    fun applyIfAlarm(activity: Activity, intent: Intent?) {
        if (intent?.action != SELECT_NOTIFICATION) return
        // A button ("Snooze…") opens the app for a sheet, not the alarm
        if (intent.getStringExtra("actionId") != null) return
        val payload = intent.getStringExtra("payload") ?: return
        if (!payload.contains("\"alarm\":true")) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            activity.setShowWhenLocked(true)
            activity.setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            activity.window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
    }

    fun release(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            activity.setShowWhenLocked(false)
            activity.setTurnScreenOn(false)
        } else {
            @Suppress("DEPRECATION")
            activity.window.clearFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
    }
}

/**
 * Time zone or clock changed, phone rebooted, app updated: re-plan every
 * reminder in Dart (the same background entry point the widgets use), so a
 * 9:00 reminder still rings at 9:00 local time after landing in another
 * time zone.
 */
class TimeChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            HomeWidgetBackgroundIntent
                .getBroadcast(context, Uri.parse("todolist://resync"))
                .send()
        } catch (e: Exception) {
            // The app hasn't run yet (no Dart callback registered): nothing to re-plan
        }
    }
}
