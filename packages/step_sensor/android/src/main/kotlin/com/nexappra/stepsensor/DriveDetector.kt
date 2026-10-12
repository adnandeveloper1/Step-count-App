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

    private fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, DriveTransitionReceiver::class.java)
        // Mutable: Play Services adds the transition result to the intent.
        val mutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
        return PendingIntent.getBroadcast(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or mutable)
    }
}

// Receives vehicle transitions from Play Services, also while the app is closed.
class DriveTransitionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
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
