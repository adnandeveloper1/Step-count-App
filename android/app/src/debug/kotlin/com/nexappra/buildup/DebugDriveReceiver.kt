package com.nexappra.buildup

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.nexappra.stepsensor.DriveDetector

// Debug builds only: fakes a vehicle transition so drive removal can be
// checked without driving. See docs/verification.md for the adb commands.
class DebugDriveReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val isEnter = when (intent.getStringExtra("type")) {
            "enter" -> true
            "exit" -> false
            else -> return
        }
        val pending = goAsync()
        val transition = DriveDetector.Transition(isEnter, System.currentTimeMillis())
        DriveDetector.record(context.applicationContext, listOf(transition)) {
            pending.finish()
        }
    }
}
