package com.nexappra.buildup.native_health

import android.content.Context
import android.content.SharedPreferences
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NativeHealthPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var context: Context? = null

    companion object {
        private const val PREFS_NAME = "health_services_native_cache"
        private const val KEY_LAST_STEPS = "last_known_absolute_steps"
        private const val SENSOR_WAIT_MS = 3000L
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.buildup.app/health_services")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getHardwareSteps" -> getHardwareSteps(result)
            "getAndroidApiLevel" -> result.success(android.os.Build.VERSION.SDK_INT)
            else -> result.notImplemented()
        }
    }

    private fun prefs(ctx: Context): SharedPreferences =
        ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun cacheSteps(ctx: Context, steps: Int) {
        prefs(ctx).edit().putInt(KEY_LAST_STEPS, steps).apply()
    }

    private fun getCachedSteps(ctx: Context): Int =
        prefs(ctx).getInt(KEY_LAST_STEPS, -2)

    private fun getHardwareSteps(result: MethodChannel.Result) {
        val currentContext = context
        if (currentContext == null) {
            result.error("NO_CONTEXT", "Context is null", null)
            return
        }

        val sensorManager = currentContext.getSystemService(Context.SENSOR_SERVICE) as SensorManager
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
                    val steps = event.values[0].toInt()
                    isResultSent = true
                    sensorManager.unregisterListener(this)
                    handler.removeCallbacksAndMessages(null)
                    cacheSteps(currentContext, steps)
                    result.success(steps)
                }
            }

            override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
        }

        handler.postDelayed({
            if (!isResultSent) {
                isResultSent = true
                sensorManager.unregisterListener(listener)
                val cached = getCachedSteps(currentContext)
                result.success(cached)
            }
        }, SENSOR_WAIT_MS)

        sensorManager.registerListener(listener, stepSensor, SensorManager.SENSOR_DELAY_FASTEST)
    }
}
