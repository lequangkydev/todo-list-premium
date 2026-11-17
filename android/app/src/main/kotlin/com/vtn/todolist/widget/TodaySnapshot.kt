package com.vtn.todolist.widget

import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * What the widgets show, written by the app as JSON (see the Dart
 * `WidgetSnapshot`). Every label is already translated there.
 */
data class TodaySnapshot(
    val open: Int,
    val done: Int,
    val items: List<Item>,
    val labels: JSONObject,
) {
    data class Item(
        val id: String,
        val title: String,
        val time: String?,
        val priority: Int,
        val late: Boolean,
    )

    fun label(key: String, fallback: String = ""): String = labels.optString(key, fallback)

    /** "3 tasks left" for the current count */
    val leftLabel: String
        get() = labels.optJSONObject("left")?.optString(open.toString()) ?: ""

    companion object {
        const val KEY = "today_snapshot"

        fun parse(json: String?): TodaySnapshot? {
            if (json.isNullOrEmpty()) return null
            return try {
                val root = JSONObject(json)
                val array = root.optJSONArray("items") ?: JSONArray()
                val items = (0 until array.length()).map { i ->
                    val o = array.getJSONObject(i)
                    Item(
                        id = o.getString("id"),
                        title = o.optString("title"),
                        time = if (o.isNull("time")) null else o.optString("time"),
                        priority = o.optInt("p"),
                        late = o.optBoolean("late"),
                    )
                }
                TodaySnapshot(
                    open = root.optInt("open"),
                    done = root.optInt("done"),
                    items = items,
                    labels = root.optJSONObject("l") ?: JSONObject(),
                )
            } catch (e: Exception) {
                null
            }
        }

        /**
         * Removes a ticked task right away, before the app has saved it, so
         * the widget responds instantly.
         */
        fun markDone(prefs: SharedPreferences, id: String) {
            val json = prefs.getString(KEY, null) ?: return
            try {
                val root = JSONObject(json)
                val items = root.optJSONArray("items") ?: return
                val kept = JSONArray()
                var removed = false
                for (i in 0 until items.length()) {
                    val item = items.getJSONObject(i)
                    if (item.optString("id") == id) removed = true else kept.put(item)
                }
                if (!removed) return
                root.put("items", kept)
                root.put("open", (root.optInt("open") - 1).coerceAtLeast(0))
                root.put("done", root.optInt("done") + 1)
                prefs.edit().putString(KEY, root.toString()).commit()
            } catch (e: Exception) {
                // Leave the snapshot alone; the app rewrites it anyway
            }
        }
    }
}
