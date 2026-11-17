package com.vtn.todolist

import android.content.Intent
import android.os.Bundle
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.example.bindinghelper.BindingNotificationManager
import com.example.bindinghelper.NotificationCallHandler
import com.vtn.todolist.backup.BackupFolderChannel
import com.vtn.todolist.reminders.AlarmLaunch
import com.vtn.todolist.reminders.ReminderChannel
import com.vtn.todolist.util.method_handler.PermissionHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.adjust.helper.AdjustChannel
import com.vtn.global.base.flutter.RegularNativeFactories

class MainActivity : FlutterActivity() {
    private var notificationCallHandler: NotificationCallHandler? = null
    private var backupFolder: BackupFolderChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AlarmLaunch.applyIfAlarm(this, intent)
        BindingNotificationManager.init(
            this,
            MainActivity::class.java,
            R.drawable.ic_notification,
        )
        BindingNotificationManager.onRestart(this, intent, onNotificationClicked = {
            notificationCallHandler?.channel?.invokeMethod(
                "openNotify",
                mapOf(
                    "fromSplash" to true,
                ),
            )
        })

    }


    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        AlarmLaunch.applyIfAlarm(this, intent)
        BindingNotificationManager.onRestart(this, intent, onNotificationClicked = {
            notificationCallHandler?.channel?.invokeMethod(
                "openNotify",
                mapOf(
                    "fromSplash" to false,
                ),
            )
        })
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        notificationCallHandler = NotificationCallHandler(
            context = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger
        )
        AdjustChannel(this, flutterEngine.dartExecutor.binaryMessenger)

        PermissionHandler(
            context = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger
        )
        ReminderChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        backupFolder = BackupFolderChannel(this, flutterEngine.dartExecutor.binaryMessenger)

        RegularNativeFactories.register(flutterEngine, applicationContext)
    }

    // The backup folder picker answers here
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (backupFolder?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        RegularNativeFactories.unregister(flutterEngine)
    }
}
