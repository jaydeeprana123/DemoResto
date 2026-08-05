package com.innies.smartkitchenpos

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.innies.smartkitchenpos/kitchen_alerts",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "ensureChannels" -> {
                    KitchenAlertNotifications.ensureChannels(applicationContext)
                    result.success(null)
                }
                "showAlert" -> {
                    val soundKey = call.argument<String>("soundKey") ?: "phone_bell"
                    val title = call.argument<String>("title") ?: "Kitchen alert"
                    val body = call.argument<String>("body") ?: ""
                    KitchenAlertNotifications.showAlert(
                        applicationContext,
                        soundKey,
                        title,
                        body,
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
