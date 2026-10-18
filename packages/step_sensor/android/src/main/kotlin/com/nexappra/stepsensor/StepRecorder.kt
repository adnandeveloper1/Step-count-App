package com.nexappra.stepsensor

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.fitness.FitnessLocal
import com.google.android.gms.fitness.LocalRecordingClient
import com.google.android.gms.fitness.data.LocalDataType
import com.google.android.gms.fitness.data.LocalField
import com.google.android.gms.fitness.request.LocalDataReadRequest
import java.util.concurrent.TimeUnit

// Steps minute by minute from Play Services' Recording API, which counts on
// the device while the app is closed and keeps up to 10 days, but only from
// the first subscription on. Lets the activity screen place steps between
// background syncs, which Android can hold back for hours.
object StepRecorder {
    private const val PREFS = "step_sensor_recorder"

    // When the first subscription succeeded: no steps before it.
    private const val KEY_SINCE = "sinceMs"

    // Subscribes to step counts; subscribing again does nothing. Calls
    // [onResult] with false when Play Services is too old or missing, or the
    // Physical activity permission is not granted.
    fun start(context: Context, onResult: (Boolean) -> Unit) {
        if (!isAvailable(context)) {
            onResult(false)
            return
        }
        try {
            FitnessLocal.getLocalRecordingClient(context)
                .subscribe(LocalDataType.TYPE_STEP_COUNT_DELTA)
                .addOnSuccessListener {
                    val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    if (!prefs.contains(KEY_SINCE)) {
                        prefs.edit().putLong(KEY_SINCE, System.currentTimeMillis()).apply()
                    }
                    onResult(true)
                }
                .addOnFailureListener { onResult(false) }
        } catch (e: RuntimeException) {
            // Play Services threw instead of failing the task (a
            // SecurityException, say); the call must still be answered.
            onResult(false)
        }
    }

    // Steps between [startMs] and [endMs] in [bucketMinutes]-minute buckets,
    // as {"since": first subscription ms, "buckets": [[start ms, steps], ...]}
    // with empty buckets left out. Null when there is no subscription or the
    // read failed.
    fun read(
        context: Context,
        startMs: Long,
        endMs: Long,
        bucketMinutes: Int,
        onResult: (Map<String, Any>?) -> Unit,
    ) {
        val since = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(KEY_SINCE, -1L)
        if (since < 0 || endMs <= startMs || !isAvailable(context)) {
            onResult(null)
            return
        }
        try {
            val request = LocalDataReadRequest.Builder()
                .aggregate(LocalDataType.TYPE_STEP_COUNT_DELTA)
                .bucketByTime(bucketMinutes, TimeUnit.MINUTES)
                .setTimeRange(startMs, endMs, TimeUnit.MILLISECONDS)
                .build()
            FitnessLocal.getLocalRecordingClient(context)
                .readData(request)
                .addOnSuccessListener { response ->
                    val buckets = try {
                        response.buckets.mapNotNull { bucket ->
                            val steps = bucket.dataSets.sumOf { set ->
                                set.dataPoints.sumOf { it.getValue(LocalField.FIELD_STEPS).asInt() }
                            }
                            if (steps > 0) listOf(bucket.getStartTime(TimeUnit.MILLISECONDS), steps) else null
                        }
                    } catch (e: RuntimeException) {
                        null
                    }
                    onResult(buckets?.let { mapOf("since" to since, "buckets" to it) })
                }
                .addOnFailureListener { onResult(null) }
        } catch (e: RuntimeException) {
            // Thrown instead of failing the task; the call must still be answered.
            onResult(null)
        }
    }

    private fun isAvailable(context: Context): Boolean =
        GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(
            context,
            LocalRecordingClient.LOCAL_RECORDING_CLIENT_MIN_VERSION_CODE,
        ) == ConnectionResult.SUCCESS && hasPermission(context)

    private fun hasPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            context.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) ==
            PackageManager.PERMISSION_GRANTED
}
