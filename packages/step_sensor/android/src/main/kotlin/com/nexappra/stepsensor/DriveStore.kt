package com.nexappra.stepsensor

import android.content.Context
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

    @Synchronized
    fun enter(context: Context, steps: Int, atMs: Long) {
        val drives = load(context)
        // Still in a vehicle: keep the first enter.
        if (drives.lastOrNull()?.isNull("exitSteps") == true) return
        val prefs = prefs(context)
        // Ids never repeat, so Dart can tell which drives it already applied.
        val id = prefs.getInt(KEY_NEXT_ID, 1)
        drives.add(
            JSONObject()
                .put("id", id)
                .put("enterSteps", stepsOrUnknown(steps))
                .put("enterMs", atMs)
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
        open.put("exitSteps", stepsOrUnknown(steps)).put("exitMs", atMs)
        save(context, drives)
    }

    @Synchronized
    fun all(context: Context): List<Map<String, Any?>> = load(context).map { drive ->
        mapOf(
            "id" to drive.getInt("id"),
            "enterSteps" to drive.getInt("enterSteps"),
            "enterMs" to drive.getLong("enterMs"),
            "exitSteps" to if (drive.isNull("exitSteps")) null else drive.getInt("exitSteps"),
            "exitMs" to if (drive.isNull("exitMs")) null else drive.getLong("exitMs"),
        )
    }

    // Deletes finished drives with these ids; an open drive is never deleted.
    @Synchronized
    fun remove(context: Context, ids: Collection<Int>) {
        val drives = load(context)
        save(context, drives.filterNot { it.getInt("id") in ids && !it.isNull("exitSteps") })
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
