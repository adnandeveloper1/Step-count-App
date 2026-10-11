package com.nexappra.buildup

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val channelName = "com.buildup.app/health_services"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "getHardwareSteps") {
                getHardwareSteps(result)
            } else if (call.method == "getAndroidApiLevel") {
                result.success(android.os.Build.VERSION.SDK_INT)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getHardwareSteps(result: MethodChannel.Result) {
        val sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
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
                    result.success(steps)
                }
            }
            override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
        }

        // 30-second timeout returning -2 to prevent baseline destruction
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