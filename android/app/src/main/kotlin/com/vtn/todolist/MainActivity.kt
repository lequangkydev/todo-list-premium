package com.vtn.todolist

import android.content.Intent
import android.os.Bundle
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.example.bindinghelper.BindingNotificationManager
import com.example.bindinghelper.NotificationCallHandler
import com.vtn.todolist.util.method_handler.PermissionHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.adjust.helper.AdjustChannel
import com.vtn.global.base.flutter.RegularNativeFactories

class MainActivity : FlutterActivity() {
    private var notificationCallHandler: NotificationCallHandler? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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

        RegularNativeFactories.register(flutterEngine, applicationContext)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        RegularNativeFactories.unregister(flutterEngine)
    }
}
