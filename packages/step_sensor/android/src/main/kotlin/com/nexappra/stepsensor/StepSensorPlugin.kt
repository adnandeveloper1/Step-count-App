package com.nexappra.stepsensor

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

// Registered as a plugin (not in MainActivity) so the channel also exists on the
// headless engine WorkManager starts for background step syncs.
class StepSensorPlugin : FlutterPlugin {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.buildup.app/health_services")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                // Cumulative steps since boot, -1 without a step counter, or -2
                // if the sensor did not report within the timeout.
                "getHardwareSteps" -> StepCounterReader.read(context, 30000) { result.success(it) }
                "getAndroidApiLevel" -> result.success(Build.VERSION.SDK_INT)
                "isBackgroundRestricted" -> result.success(isBackgroundRestricted())
                "startDriveDetection" -> DriveDetector.start(context) { result.success(it) }
                "checkStillDriving" -> DriveDetector.checkStillDriving(context) { result.success(it) }
                "startStepRecording" -> StepRecorder.start(context) { result.success(it) }
                "getRecordedSteps" -> {
                    val startMs = call.argument<Number>("startMs")?.toLong()
                    val endMs = call.argument<Number>("endMs")?.toLong()
                    if (startMs == null || endMs == null) {
                        result.success(null)
                    } else {
                        StepRecorder.read(context, startMs, endMs, call.argument<Int>("bucketMinutes") ?: 1) {
                            result.success(it)
                        }
                    }
                }
                "getDrives" -> result.success(DriveStore.all(context))
                "removeDrives" -> {
                    DriveStore.remove(context, call.arguments<List<Int>>().orEmpty())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // The user (or the phone's battery suggestions) set the app's battery use
    // to Restricted; Android 9+ only.
    private fun isBackgroundRestricted(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
            (context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).isBackgroundRestricted

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
