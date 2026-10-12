package com.nexappra.stepsensor

import android.content.Context
import android.os.Build
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject

// Drives recorded from vehicle transitions, kept in this plugin's own
// SharedPreferences: only the Dart isolate that holds storage writes Hive.
// Dart folds finished drives into today's step baseline, then deletes them.
object DriveStore {
    // Saved in place of a step reading the sensor did not return in time.
    const val UNKNOWN_STEPS = -1

    private const val PREFS = "step_sensor_drives"
    private const val KEY_DRIVES = "drives"
    private const val KEY_NEXT_ID = "nextId"
    private const val MAX_DRIVES = 20

    // Same as openDriveTimeout in step_counter_math.dart.
    private const val OPEN_DRIVE_TIMEOUT_MS = 4 * 60 * 60 * 1000L

    @Synchronized
    fun enter(context: Context, steps: Int, atMs: Long) {
        val drives = load(context)
        // Still in a vehicle: keep the first enter, unless that drive's exit
        // was missed (Dart stops applying it and deletes it).
        val last = drives.lastOrNull()
        if (last != null && last.isNull("exitSteps") && atMs - last.getLong("enterMs") < OPEN_DRIVE_TIMEOUT_MS) return
        val prefs = prefs(context)
        // Ids never repeat, so Dart can tell which drives it already applied.
        val id = prefs.getInt(KEY_NEXT_ID, 1)
        drives.add(
            JSONObject()
                .put("id", id)
                .put("enterSteps", stepsOrUnknown(steps))
                .put("enterMs", atMs)
                .put("enterBoot", bootCount(context))
                .put("exitSteps", JSONObject.NULL)
                .put("exitMs", JSONObject.NULL),
        )
        prefs.edit()
            .putInt(KEY_NEXT_ID, id + 1)
            .putString(KEY_DRIVES, JSONArray(drives.takeLast(MAX_DRIVES)).toString())
            .commit()
    }

    @Synchronized
    fun exit(context: Context, steps: Int, atMs: Long) {
        val drives = load(context)
        val open = drives.lastOrNull()?.takeIf { it.isNull("exitSteps") } ?: return
        open.put("exitSteps", stepsOrUnknown(steps))
            .put("exitMs", atMs)
            .put("exitBoot", bootCount(context))
        save(context, drives)
    }

    // At boot: the phone restarted mid-drive, and transition updates were
    // dropped, so the exit may never come. End the drive with an unknown exit
    // so the walking after the restart counts; if the user is still in the
    // vehicle, the next enter starts a new drive.
    @Synchronized
    fun endOpenDriveAtBoot(context: Context) {
        val drives = load(context)
        val open = drives.lastOrNull()?.takeIf { it.isNull("exitSteps") } ?: return
        open.put("exitSteps", UNKNOWN_STEPS)
            .put("exitMs", System.currentTimeMillis())
            .put("exitBoot", bootCount(context))
        save(context, drives)
    }

    // The drives for Dart. A reading from before the phone last restarted is
    // flagged, because the step counter has since restarted from zero.
    @Synchronized
    fun all(context: Context): List<Map<String, Any?>> {
        val boot = bootCount(context)
        fun beforeBoot(drive: JSONObject, key: String) =
            boot != NO_BOOT_COUNT && drive.optInt(key, boot).let { it != NO_BOOT_COUNT && it != boot }
        return load(context).map { drive ->
            mapOf(
                "id" to drive.getInt("id"),
                "enterSteps" to drive.getInt("enterSteps"),
                "enterMs" to drive.getLong("enterMs"),
                "enterBeforeBoot" to beforeBoot(drive, "enterBoot"),
                "exitSteps" to if (drive.isNull("exitSteps")) null else drive.getInt("exitSteps"),
                "exitMs" to if (drive.isNull("exitMs")) null else drive.getLong("exitMs"),
                "exitBeforeBoot" to (!drive.isNull("exitSteps") && beforeBoot(drive, "exitBoot")),
            )
        }
    }

    // Deletes drives Dart has applied: finished ones, and open ones whose exit
    // never came (see openDriveTimeout in step_counter_math.dart).
    @Synchronized
    fun remove(context: Context, ids: Collection<Int>) {
        val drives = load(context)
        save(context, drives.filterNot { it.getInt("id") in ids })
    }

    private const val NO_BOOT_COUNT = -1

    // How many times the phone has started; tells readings from different
    // boots apart.
    private fun bootCount(context: Context): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, NO_BOOT_COUNT)
        } else {
            NO_BOOT_COUNT
        }

    private fun stepsOrUnknown(steps: Int) = if (steps > 0) steps else UNKNOWN_STEPS

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun load(context: Context): MutableList<JSONObject> {
        val json = JSONArray(prefs(context).getString(KEY_DRIVES, "[]"))
        return MutableList(json.length()) { json.getJSONObject(it) }
    }

    // commit, not apply: a receiver's process can be killed right after.
    private fun save(context: Context, drives: List<JSONObject>) {
        prefs(context).edit().putString(KEY_DRIVES, JSONArray(drives).toString()).commit()
    }
}
