package com.app.finity

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.app.finity/package_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Add method channel for package info as fallback
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPackageInfo" -> {
                    try {
                        val packageInfo = packageManager.getPackageInfo(packageName, 0)
                        val info = mapOf(
                            "appName" to "Finity",
                            "packageName" to packageName,
                            "version" to packageInfo.versionName,
                            "buildNumber" to packageInfo.longVersionCode.toString()
                        )
                        result.success(info)
                    } catch (e: Exception) {
                        result.error("PACKAGE_INFO_ERROR", "Failed to get package info", e.localizedMessage)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
