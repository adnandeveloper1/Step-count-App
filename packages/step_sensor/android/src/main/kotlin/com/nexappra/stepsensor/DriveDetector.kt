package com.nexappra.stepsensor

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityRecognitionResult
import com.google.android.gms.location.ActivityTransition
import com.google.android.gms.location.ActivityTransitionRequest
import com.google.android.gms.location.ActivityTransitionResult
import com.google.android.gms.location.DetectedActivity

// Learns when the user gets into and out of a vehicle from Play Services'
// Activity Recognition Transition API, which reports even while the app is
// closed, and saves the step counter reading at each (see DriveStore).
object DriveDetector {
    // A receiver has about 10 s before the system may kill it.
    private const val SENSOR_TIMEOUT_MS = 8000L

    // "Still driving?" checks: how often Play Services reports while one
    // runs, how long one may run without a clear answer, and the shortest
    // gap between two (the app asks every minute while it is open).
    private const val CHECK_INTERVAL_MS = 10_000L
    private const val CHECK_MAX_MS = 5 * 60 * 1000L
    private const val CHECK_MIN_GAP_MS = 10 * 60 * 1000L
    private const val PREFS = "step_sensor_drive_check"
    private const val KEY_CHECK_STARTED = "startedMs"

    // How sure Play Services must be (0-100) to confirm or end a drive.
    private const val VEHICLE_CONFIDENCE = 50
    private const val ON_FOOT_CONFIDENCE = 75

    // Registers for vehicle enter / exit transitions. Calls [onResult] with
    // false when Play Services or the Physical activity permission is missing.
    @SuppressLint("MissingPermission") // Checked in hasPermission.
    fun start(context: Context, onResult: (Boolean) -> Unit) {
        val available = GoogleApiAvailability.getInstance()
            .isGooglePlayServicesAvailable(context) == ConnectionResult.SUCCESS
        if (!available || !hasPermission(context)) {
            onResult(false)
            return
        }
        val transitions = listOf(
            ActivityTransition.ACTIVITY_TRANSITION_ENTER,
            ActivityTransition.ACTIVITY_TRANSITION_EXIT,
        ).map {
            ActivityTransition.Builder()
                .setActivityType(DetectedActivity.IN_VEHICLE)
                .setActivityTransition(it)
                .build()
        }
        // Registering again replaces the earlier registration (same PendingIntent).
        ActivityRecognition.getClient(context)
            .requestActivityTransitionUpdates(ActivityTransitionRequest(transitions), pendingIntent(context))
            .addOnSuccessListener { onResult(true) }
            .addOnFailureListener { onResult(false) }
    }

    // Asks Play Services whether the user is still in a vehicle; the answer
    // arrives at DriveTransitionReceiver (see onCheckResult). Calls
    // [onResult] with false when it could not ask.
    @SuppressLint("MissingPermission") // Checked in hasPermission.
    fun checkStillDriving(context: Context, onResult: (Boolean) -> Unit) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        if (now - prefs.getLong(KEY_CHECK_STARTED, 0L) < CHECK_MIN_GAP_MS) {
            onResult(true)
            return
        }
        if (!DriveStore.hasOpenDrive(context) || !hasPermission(context)) {
            onResult(false)
            return
        }
        prefs.edit().putLong(KEY_CHECK_STARTED, now).commit()
        ActivityRecognition.getClient(context)
            .requestActivityUpdates(CHECK_INTERVAL_MS, checkPendingIntent(context))
            .addOnSuccessListener { onResult(true) }
            .addOnFailureListener { onResult(false) }
    }

    // One report during a check: confirm the drive if the user is in a
    // vehicle, end it if they are clearly on foot, otherwise wait for the
    // next report until the check runs out.
    fun onCheckResult(context: Context, result: ActivityRecognitionResult, done: () -> Unit) {
        val now = System.currentTimeMillis()
        val onFoot = listOf(
            DetectedActivity.ON_FOOT,
            DetectedActivity.WALKING,
            DetectedActivity.RUNNING,
            DetectedActivity.ON_BICYCLE,
        ).maxOf { result.getActivityConfidence(it) }
        val started = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getLong(KEY_CHECK_STARTED, 0L)
        when {
            !DriveStore.hasOpenDrive(context) -> {
                stopCheck(context)
                done()
            }
            result.getActivityConfidence(DetectedActivity.IN_VEHICLE) >= VEHICLE_CONFIDENCE -> {
                DriveStore.confirm(context, now)
                stopCheck(context)
                done()
            }
            onFoot >= ON_FOOT_CONFIDENCE -> {
                stopCheck(context)
                record(context, listOf(Transition(isEnter = false, atMs = now)), done)
            }
            else -> {
                if (now - started > CHECK_MAX_MS) stopCheck(context)
                done()
            }
        }
    }

    @SuppressLint("MissingPermission") // Removing updates needs no permission.
    private fun stopCheck(context: Context) {
        ActivityRecognition.getClient(context).removeActivityUpdates(checkPendingIntent(context))
    }

    // An enter (true) or exit (false) and when it happened.
    data class Transition(val isEnter: Boolean, val atMs: Long)

    // Reads the step counter once and saves [transitions] in order: one
    // delivery can hold both an enter and an exit.
    fun record(context: Context, transitions: List<Transition>, done: () -> Unit) {
        StepCounterReader.read(context, SENSOR_TIMEOUT_MS) { steps ->
            for (t in transitions) {
                if (t.isEnter) DriveStore.enter(context, steps, t.atMs) else DriveStore.exit(context, steps, t.atMs)
            }
            done()
        }
    }

    private fun hasPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            context.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) ==
            PackageManager.PERMISSION_GRANTED

    private fun pendingIntent(context: Context) = broadcast(context, requestCode = 0)

    private fun checkPendingIntent(context: Context) = broadcast(context, requestCode = 1)

    private fun broadcast(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, DriveTransitionReceiver::class.java)
        // Mutable: Play Services adds its result to the intent.
        val mutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
        return PendingIntent.getBroadcast(context, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT or mutable)
    }
}

// Receives vehicle transitions and "still driving?" check reports from Play
// Services, also while the app is closed.
class DriveTransitionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (ActivityRecognitionResult.hasResult(intent)) {
            val result = ActivityRecognitionResult.extractResult(intent) ?: return
            val pending = goAsync()
            DriveDetector.onCheckResult(context.applicationContext, result) { pending.finish() }
            return
        }
        if (!ActivityTransitionResult.hasResult(intent)) return
        val events = ActivityTransitionResult.extractResult(intent)?.transitionEvents ?: return
        val nowMs = System.currentTimeMillis()
        val nowNanos = SystemClock.elapsedRealtimeNanos()
        val transitions = events
            .filter { it.activityType == DetectedActivity.IN_VEHICLE }
            .sortedBy { it.elapsedRealTimeNanos }
            .map {
                // When the transition happened; it can arrive a little later.
                DriveDetector.Transition(
                    isEnter = it.transitionType == ActivityTransition.ACTIVITY_TRANSITION_ENTER,
                    atMs = nowMs - (nowNanos - it.elapsedRealTimeNanos) / 1_000_000,
                )
            }
        if (transitions.isEmpty()) return
        val pending = goAsync()
        DriveDetector.record(context.applicationContext, transitions) { pending.finish() }
    }
}

// Transition updates are dropped when the phone restarts or the app is
// updated, so register again then. The app and the background task also
// register on every start.
class DriveRestartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val app = context.applicationContext
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> DriveStore.endOpenDriveAtBoot(app)
            Intent.ACTION_MY_PACKAGE_REPLACED -> {}
            else -> return
        }
        val pending = goAsync()
        // Finish once: when Play Services answers, or before the receiver's
        // ~10 s limit if it does not.
        val handler = Handler(Looper.getMainLooper())
        var finished = false
        val finish = {
            if (!finished) {
                finished = true
                handler.removeCallbacksAndMessages(null)
                pending.finish()
            }
        }
        handler.postDelayed(finish, 8000)
        DriveDetector.start(app) { handler.post(finish) }
    }
}
