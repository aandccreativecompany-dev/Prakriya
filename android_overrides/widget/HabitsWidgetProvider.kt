package ai.aandccreative.prakriya

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar
import org.json.JSONArray
import org.json.JSONObject

/**
 * Prakriyā home-screen widget: a small dashboard plus the to-do list and
 * habit checklist. The Flutter side writes everything as text into shared
 * preferences (look, which blocks to show and in what order, the lists);
 * this class turns that into RemoteViews.
 *
 * Ticking a task or habit works right on the widget: the new state is saved
 * to the same preferences and redrawn at once, and the change is queued in
 * "widget_pending" for the app to apply the next time it opens. Tapping a
 * title opens the app on the matching screen.
 */
class HabitsWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_TOGGLE = "ai.aandccreative.prakriya.WIDGET_TOGGLE"
        const val ACTION_LAUNCH = "es.antonborri.home_widget.action.LAUNCH"
    }

    private class Palette(
        val key: String,
        val background: Int,
        val title: Int,
        val text: Int,
        val muted: Int,
        val accent: Int,
        val done: Int
    )

    private fun palette(style: String?): Palette {
        return when (style) {
            "sunrise" -> Palette("sunrise", R.drawable.widget_bg_sunrise,
                Color.parseColor("#C2531A"), Color.parseColor("#3A2216"),
                Color.parseColor("#8A5A3C"), Color.parseColor("#E2661F"),
                Color.parseColor("#B59A86"))
            "forest" -> Palette("forest", R.drawable.widget_bg_forest,
                Color.parseColor("#7BE0B2"), Color.parseColor("#E6F5EC"),
                Color.parseColor("#8FBFA6"), Color.parseColor("#5ED39A"),
                Color.parseColor("#6E9C87"))
            "paper" -> Palette("paper", R.drawable.widget_bg_paper,
                Color.parseColor("#5A32A8"), Color.parseColor("#2B2140"),
                Color.parseColor("#8E84A3"), Color.parseColor("#6B3FC4"),
                Color.parseColor("#A89FB8"))
            else -> Palette("dusk", R.drawable.widget_bg_dusk,
                Color.parseColor("#F2B93B"), Color.parseColor("#F4EEFF"),
                Color.parseColor("#A99BD0"), Color.parseColor("#F2B93B"),
                Color.parseColor("#7F72A8"))
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, build(context, appWidgetManager, id, widgetData))
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val data = HomeWidgetPlugin.getData(context)
        appWidgetManager.updateAppWidget(
            appWidgetId, build(context, appWidgetManager, appWidgetId, data))
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TOGGLE) {
            handleToggle(context, intent)
            return
        }
        super.onReceive(context, intent)
    }

    // ---- Toggling from the widget ----

    private fun handleToggle(context: Context, intent: Intent) {
        val kind = intent.getStringExtra("kind") ?: return
        val key = intent.getStringExtra("key") ?: return
        val index = intent.getIntExtra("index", -1)
        val prefs = HomeWidgetPlugin.getData(context)
        val listKey = if (kind == "task") "widget_tasks" else "widget_habits"
        try {
            val arr = JSONArray(prefs.getString(listKey, "[]") ?: "[]")
            var found = false
            var newValue = false
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                val match = if (kind == "task") {
                    o.optInt("i", -2) == index && o.optString("t") == key
                } else {
                    o.optString("id") == key
                }
                if (match) {
                    newValue = !o.optBoolean("d", false)
                    o.put("d", newValue)
                    found = true
                    break
                }
            }
            if (!found) return

            // Queue the change for the app; a later tap on the same item
            // replaces the earlier one.
            val pending = JSONArray(prefs.getString("widget_pending", "[]") ?: "[]")
            val kept = JSONArray()
            for (i in 0 until pending.length()) {
                val p = pending.getJSONObject(i)
                val same = p.optString("k") == kind &&
                    p.optString("key") == key &&
                    p.optInt("i", -2) == index
                if (!same) kept.put(p)
            }
            val entry = JSONObject()
            entry.put("k", kind)
            entry.put("key", key)
            entry.put("i", index)
            entry.put("v", newValue)
            entry.put("day", prefs.getString("widget_day", "") ?: "")
            kept.put(entry)

            prefs.edit()
                .putString(listKey, arr.toString())
                .putString("widget_pending", kept.toString())
                .apply()
        } catch (e: Exception) {
            return
        }
        refreshAll(context)
    }

    private fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, HabitsWidgetProvider::class.java))
        val data = HomeWidgetPlugin.getData(context)
        for (id in ids) {
            manager.updateAppWidget(id, build(context, manager, id, data))
        }
    }

    // ---- Pending intents ----

    private fun openIntent(context: Context, target: String): PendingIntent? {
        val component = context.packageManager
            .getLaunchIntentForPackage(context.packageName)?.component ?: return null
        val intent = Intent()
        intent.component = component
        intent.action = ACTION_LAUNCH
        intent.data = Uri.parse("prakriya://widget/open/$target")
        return PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun toggleIntent(context: Context, kind: String, key: String, index: Int): PendingIntent {
        val intent = Intent(context, HabitsWidgetProvider::class.java)
        intent.action = ACTION_TOGGLE
        intent.data = Uri.parse("prakriya://widget/toggle/$kind/$index/" + Uri.encode(key))
        intent.putExtra("kind", kind)
        intent.putExtra("key", key)
        intent.putExtra("index", index)
        return PendingIntent.getBroadcast(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    // ---- Drawing ----

    private fun todayKey(): String {
        val c = Calendar.getInstance()
        return String.format(
            "%04d-%02d-%02d", c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1,
            c.get(Calendar.DAY_OF_MONTH))
    }

    private fun readArray(data: SharedPreferences, key: String): JSONArray {
        return try {
            JSONArray(data.getString(key, "[]") ?: "[]")
        } catch (e: Exception) {
            JSONArray()
        }
    }

    private fun build(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        data: SharedPreferences
    ): RemoteViews {
        val p = palette(data.getString("widget_style", "dusk"))
        val pkg = context.packageName
        val views = RemoteViews(pkg, R.layout.habits_widget)
        views.setInt(R.id.widget_root, "setBackgroundResource", p.background)

        val options = manager.getAppWidgetOptions(id)
        var height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180)
        if (height <= 0) height = 180
        var budget = height - 24 - 40 - 6

        // Header
        views.setTextViewText(R.id.widget_title, "Prakriyā")
        views.setTextColor(R.id.widget_title, p.title)
        val dateLabel = data.getString("widget_date", "") ?: ""
        views.setTextViewText(R.id.widget_date, dateLabel)
        views.setTextColor(R.id.widget_date, p.muted)
        views.setViewVisibility(R.id.widget_date, if (dateLabel.isEmpty()) View.GONE else View.VISIBLE)
        views.setTextColor(R.id.widget_add, p.accent)
        val openDash = openIntent(context, "dashboard")
        val openAdd = openIntent(context, "addtask")
        if (openDash != null) {
            views.setOnClickPendingIntent(R.id.widget_root, openDash)
            views.setOnClickPendingIntent(R.id.widget_head, openDash)
        }
        if (openAdd != null) views.setOnClickPendingIntent(R.id.widget_add, openAdd)

        // Data
        val day = data.getString("widget_day", "") ?: ""
        val stale = day.isNotEmpty() && day != todayKey()
        val showDoneTasks = (data.getString("widget_show_done_tasks", "1") ?: "1") == "1"
        val allTasks = if (stale) JSONArray() else readArray(data, "widget_tasks")
        val habits = if (stale) JSONArray() else readArray(data, "widget_habits")
        var tasksDone = 0
        for (i in 0 until allTasks.length()) {
            if (allTasks.getJSONObject(i).optBoolean("d", false)) tasksDone++
        }
        var habitsDone = 0
        for (i in 0 until habits.length()) {
            if (habits.getJSONObject(i).optBoolean("d", false)) habitsDone++
        }

        val blocks = readArray(data, "widget_blocks")
        views.removeAllViews(R.id.widget_content)

        for (b in 0 until blocks.length()) {
            when (blocks.optString(b)) {
                "stats" -> {
                    if (budget >= 46) {
                        val stats = readArray(data, "widget_stats")
                        if (stats.length() > 0) {
                            val child = RemoteViews(pkg, R.layout.widget_block_stats)
                            val cells = intArrayOf(R.id.stat_c1, R.id.stat_c2, R.id.stat_c3, R.id.stat_c4)
                            val values = intArrayOf(R.id.stat_v1, R.id.stat_v2, R.id.stat_v3, R.id.stat_v4)
                            val labels = intArrayOf(R.id.stat_l1, R.id.stat_l2, R.id.stat_l3, R.id.stat_l4)
                            for (i in 0 until 4) {
                                if (i < stats.length()) {
                                    val s = stats.getJSONObject(i)
                                    val kind = s.optString("k")
                                    var value = s.optString("v", "")
                                    if (kind == "habits") {
                                        value = if (stale || habits.length() == 0) "–" else "$habitsDone/${habits.length()}"
                                    } else if (kind == "tasks") {
                                        value = if (stale || allTasks.length() == 0) "–" else "$tasksDone/${allTasks.length()}"
                                    }
                                    child.setTextViewText(values[i], value)
                                    child.setTextColor(values[i], p.text)
                                    child.setTextViewText(labels[i], s.optString("l", ""))
                                    child.setTextColor(labels[i], p.muted)
                                    child.setViewVisibility(cells[i], View.VISIBLE)
                                } else {
                                    child.setViewVisibility(cells[i], View.GONE)
                                }
                            }
                            views.addView(R.id.widget_content, child)
                            budget -= 46
                        }
                    }
                }
                "progress" -> {
                    val total = habits.length() + allTasks.length()
                    if (budget >= 36 && total > 0) {
                        val done = habitsDone + tasksDone
                        val pct = (done * 100) / total
                        val child = RemoteViews(pkg, R.layout.widget_block_progress)
                        val bars = mapOf(
                            "dusk" to R.id.progress_dusk,
                            "sunrise" to R.id.progress_sunrise,
                            "forest" to R.id.progress_forest,
                            "paper" to R.id.progress_paper
                        )
                        for ((key, barId) in bars) {
                            child.setViewVisibility(barId, if (key == p.key) View.VISIBLE else View.GONE)
                        }
                        val activeBar = bars[p.key] ?: R.id.progress_dusk
                        child.setProgressBar(activeBar, 100, pct, false)
                        child.setTextViewText(
                            R.id.progress_label,
                            if (done >= total) "Everything done today" else "$done of $total done today")
                        child.setTextColor(R.id.progress_label, p.muted)
                        views.addView(R.id.widget_content, child)
                        budget -= 36
                    }
                }
                "tasks" -> {
                    budget = addList(
                        context, views, p, budget, "task", "TO-DO",
                        allTasks, stale, showDoneTasks,
                        "No tasks yet. Tap + to add one.")
                }
                "habits" -> {
                    budget = addList(
                        context, views, p, budget, "habit", "HABITS",
                        habits, stale, true,
                        "No habits selected. Pick some in the app.")
                }
                "mantra" -> {
                    val mantra = data.getString("widget_mantra", "") ?: ""
                    if (mantra.isNotEmpty() && budget >= 44) {
                        val child = RemoteViews(pkg, R.layout.widget_block_text)
                        child.setTextViewText(R.id.text_body, "“$mantra”")
                        child.setTextColor(R.id.text_body, p.text)
                        views.addView(R.id.widget_content, child)
                        budget -= 44
                    }
                }
            }
        }
        return views
    }

    /**
     * Adds a titled list (tasks or habits) as far as the remaining height
     * allows, and returns the height left over.
     */
    private fun addList(
        context: Context,
        views: RemoteViews,
        p: Palette,
        budgetIn: Int,
        kind: String,
        title: String,
        items: JSONArray,
        stale: Boolean,
        showDone: Boolean,
        emptyText: String
    ): Int {
        var budget = budgetIn
        val pkg = context.packageName
        if (budget < 24 + 26) return budget

        val open = openIntent(context, if (kind == "task") "tasks" else "dashboard")

        // Rows that should be visible.
        val rows = ArrayList<JSONObject>()
        var doneCount = 0
        for (i in 0 until items.length()) {
            val o = items.getJSONObject(i)
            if (o.optBoolean("d", false)) doneCount++
            if (showDone || !o.optBoolean("d", false)) rows.add(o)
        }

        val header = RemoteViews(pkg, R.layout.widget_block_header)
        header.setTextViewText(R.id.hdr_text, title)
        header.setTextColor(R.id.hdr_text, p.muted)
        header.setTextViewText(
            R.id.hdr_count, if (items.length() == 0) "" else "$doneCount/${items.length()}")
        header.setTextColor(R.id.hdr_count, p.muted)
        if (open != null) header.setOnClickPendingIntent(R.id.hdr_text, open)
        views.addView(R.id.widget_content, header)
        budget -= 24

        if (stale || rows.isEmpty()) {
            val note = RemoteViews(pkg, R.layout.widget_block_text)
            val text = if (stale) "New day. Tap to load today's list." else if (items.length() == 0) emptyText else "All done. Nicely done."
            note.setTextViewText(R.id.text_body, text)
            note.setTextColor(R.id.text_body, p.muted)
            if (open != null) note.setOnClickPendingIntent(R.id.text_body, open)
            views.addView(R.id.widget_content, note)
            return budget - 34
        }

        var shown = 0
        for (o in rows) {
            if (budget < 26) break
            val row = RemoteViews(pkg, R.layout.widget_row)
            val done = o.optBoolean("d", false)
            val name = if (kind == "task") o.optString("t") else o.optString("n")
            val key = if (kind == "task") o.optString("t") else o.optString("id")
            val index = if (kind == "task") o.optInt("i", -1) else -1
            row.setTextViewText(R.id.row_text, name)
            row.setTextColor(R.id.row_text, if (done) p.done else p.text)
            row.setImageViewResource(
                R.id.row_mark, if (done) R.drawable.widget_check_on else R.drawable.widget_check_off)
            row.setInt(R.id.row_mark, "setColorFilter", if (done) p.done else p.accent)
            row.setOnClickPendingIntent(R.id.row_mark, toggleIntent(context, kind, key, index))
            if (open != null) row.setOnClickPendingIntent(R.id.row_text, open)
            views.addView(R.id.widget_content, row)
            budget -= 26
            shown++
        }
        return budget
    }
}
