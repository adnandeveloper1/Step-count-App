package com.nexappra.stepsensor

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper

object StepCounterReader {
    const val NO_SENSOR = -1
    const val TIMED_OUT = -2

    // Calls [onResult] once, on the main thread, with the cumulative steps
    // since boot, NO_SENSOR if the device has no step counter, or TIMED_OUT if
    // the sensor did not report within [timeoutMs].
    fun read(context: Context, timeoutMs: Long, onResult: (Int) -> Unit) {
        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

        if (stepSensor == null) {
            onResult(NO_SENSOR)
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
                    onResult(event.values[0].toInt())
                }
            }
            override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
        }

        handler.postDelayed({
            if (!isResultSent) {
                isResultSent = true
                sensorManager.unregisterListener(listener)
                onResult(TIMED_OUT)
            }
        }, timeoutMs)

        sensorManager.registerListener(listener, stepSensor, SensorManager.SENSOR_DELAY_FASTEST)
    }
}
