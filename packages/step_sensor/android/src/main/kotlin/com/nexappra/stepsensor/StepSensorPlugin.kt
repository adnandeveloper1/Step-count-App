package com.nexappra.stepsensor

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
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
                "getHardwareSteps" -> getHardwareSteps(result)
                "getAndroidApiLevel" -> result.success(android.os.Build.VERSION.SDK_INT)
                else -> result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // Returns the cumulative steps since boot, -1 if the device has no step
    // counter, or -2 if the sensor did not report within the timeout.
    private fun getHardwareSteps(result: MethodChannel.Result) {
        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

        if (stepSensor == null) {
            result.success(-1)
            return
        }

        val handler = Handler(Looper.getMainLooper())
        var isResultSent = false

        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                if (!isResultSent) {
                    isResultSent = true
                    sensorManager.unregisterListener(this)
                    handler.removeCallbacksAndMessages(null)
                    result.success(event.values[0].toInt())
                }
            }
            override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
        }

        handler.postDelayed({
            if (!isResultSent) {
                isResultSent = true
                sensorManager.unregisterListener(listener)
                result.success(-2)
            }
        }, 30000)

        sensorManager.registerListener(listener, stepSensor, SensorManager.SENSOR_DELAY_FASTEST)
    }
}
