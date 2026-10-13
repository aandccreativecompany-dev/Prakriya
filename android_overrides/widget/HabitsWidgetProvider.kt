package ai.aandccreative.prakriya

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar
import org.json.JSONArray
import org.json.JSONObject

/**
 * Prakriyā home-screen widget: a small dashboard with the to-do list, habit
 * checklist, water tracker and week strip. The Flutter side writes everything
 * as text into shared preferences (look, which blocks to show and in what
 * order, the lists); this class turns that into RemoteViews.
 *
 * Ticking a task or habit, or logging water, works right on the widget: the
 * new state is saved to the same preferences and redrawn at once, and the
 * change is queued in "widget_pending" for the app to apply the next time it
 * opens. The widget also rolls itself over to the new day at midnight, so it
 * is correct even if the app has not been opened.
 */
class HabitsWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_TOGGLE = "ai.aandccreative.prakriya.WIDGET_TOGGLE"
        const val ACTION_LAUNCH = "es.antonborri.home_widget.action.LAUNCH"
    }

    private class Palette(
        val key: String,
        val light: Boolean,
        val background: Int,
        val title: Int,
        val text: Int,
        val muted: Int,
        val accent: Int,
        val done: Int
    )

    private fun c(hex: String): Int = Color.parseColor(hex)

    private fun palette(style: String?): Palette {
        return when (style) {
            "midnight" -> Palette("midnight", false, R.drawable.widget_bg_midnight,
                c("#FFFFFF"), c("#F2F2F5"), c("#9A9AA8"), c("#7CC4FF"), c("#70707E"))
            "ocean" -> Palette("ocean", false, R.drawable.widget_bg_ocean,
                c("#7FD8FF"), c("#EAF6FF"), c("#93BAD6"), c("#4FC3F7"), c("#6C90AA"))
            "forest" -> Palette("forest", false, R.drawable.widget_bg_forest,
                c("#7BE0B2"), c("#E6F5EC"), c("#9CC8B2"), c("#5ED39A"), c("#729F8B"))
            "graphite" -> Palette("graphite", false, R.drawable.widget_bg_graphite,
                c("#FFC857"), c("#F1F3F5"), c("#A9B0BA"), c("#FFC857"), c("#7E858F"))
            "sunrise" -> Palette("sunrise", true, R.drawable.widget_bg_sunrise,
                c("#C2531A"), c("#3A2216"), c("#7A4E32"), c("#E2661F"), c("#A48A76"))
            "rose" -> Palette("rose", true, R.drawable.widget_bg_rose,
                c("#B8264F"), c("#3B1A25"), c("#7A4A5C"), c("#D6336C"), c("#A98593"))
            "paper" -> Palette("paper", true, R.drawable.widget_bg_paper,
                c("#5A32A8"), c("#2B2140"), c("#766C8C"), c("#6B3FC4"), c("#9E95AE"))
            else -> Palette("dusk", false, R.drawable.widget_bg_dusk,
                c("#F2B93B"), c("#F4EEFF"), c("#B4A8DA"), c("#F2B93B"), c("#8A7DB0"))
        }
    }

    // ---- Entry points ----

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, build(context, appWidgetManager, id, widgetData))
        }
        scheduleMidnight(context)
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
            handleAction(context, intent)
            return
        }
        super.onReceive(context, intent)
    }

    /** A soft refresh just after midnight so the widget shows the new day. */
    private fun scheduleMidnight(context: Context) {
        try {
            val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val at = Calendar.getInstance()
            at.add(Calendar.DAY_OF_YEAR, 1)
            at.set(Calendar.HOUR_OF_DAY, 0)
            at.set(Calendar.MINUTE, 1)
            at.set(Calendar.SECOND, 0)
            at.set(Calendar.MILLISECOND, 0)
            val ids = AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, HabitsWidgetProvider::class.java))
            val intent = Intent(context, HabitsWidgetProvider::class.java)
            intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            val pending = PendingIntent.getBroadcast(
                context, 7, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            alarms.set(AlarmManager.RTC, at.timeInMillis, pending)
        } catch (e: Exception) {
            // The 30-minute system refresh still covers this.
        }
    }

    // ---- Small helpers ----

    private fun str(data: SharedPreferences, key: String, def: String): String =
        data.getString(key, def) ?: def

    private fun flag(data: SharedPreferences, key: String, def: Boolean): Boolean =
        str(data, key, if (def) "1" else "0") == "1"

    private fun intOf(data: SharedPreferences, key: String, def: Int): Int =
        str(data, key, def.toString()).toIntOrNull() ?: def

    private fun readArray(data: SharedPreferences, key: String): JSONArray {
        return try {
            JSONArray(str(data, key, "[]"))
        } catch (e: Exception) {
            JSONArray()
        }
    }

    private fun todayKey(): String {
        val cal = Calendar.getInstance()
        return String.format(
            "%04d-%02d-%02d", cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1,
            cal.get(Calendar.DAY_OF_MONTH))
    }

    private fun parseDay(key: String): Calendar? {
        val parts = key.split("-")
        if (parts.size != 3) return null
        val y = parts[0].toIntOrNull() ?: return null
        val m = parts[1].toIntOrNull() ?: return null
        val d = parts[2].toIntOrNull() ?: return null
        val cal = Calendar.getInstance()
        cal.set(y, m - 1, d, 12, 0, 0)
        return cal
    }

    // ---- New-day rollover ----

    /**
     * If the saved data is from an earlier day, move it to today: habits
     * start unticked, the list becomes tomorrow's tasks as the app last saw
     * them, water restarts and the week strip slides along.
     */
    private fun rollOver(data: SharedPreferences) {
        val day = str(data, "widget_day", "")
        val today = todayKey()
        if (day.isEmpty() || day == today) return
        val editor = data.edit()
        try {
            val habits = readArray(data, "widget_habits")
            for (i in 0 until habits.length()) {
                habits.getJSONObject(i).put("d", false)
            }
            editor.putString("widget_habits", habits.toString())

            val nextDay = str(data, "widget_next_day", "")
            val tasks = if (nextDay == today) str(data, "widget_tasks_next", "[]") else "[]"
            editor.putString("widget_tasks", tasks)
            editor.putString("widget_tasks_next", "[]")
            editor.putString("widget_next_day", "")
            editor.putString("widget_water", "0")

            // Slide the week strip.
            val from = parseDay(day)
            val to = parseDay(today)
            if (from != null && to != null) {
                val diff = ((to.timeInMillis - from.timeInMillis) / 86400000L).toInt()
                val steps = if (diff > 7) 7 else diff
                val old = readArray(data, "widget_week")
                if (steps > 0 && old.length() == 7) {
                    val letters = arrayOf("M", "T", "W", "T", "F", "S", "S")
                    val out = JSONArray()
                    for (i in steps until old.length()) out.put(old.get(i))
                    for (back in steps - 1 downTo 0) {
                        val cal = Calendar.getInstance()
                        cal.add(Calendar.DAY_OF_YEAR, -back)
                        val letter = letters[(cal.get(Calendar.DAY_OF_WEEK) + 5) % 7]
                        out.put(JSONObject().put("l", letter).put("p", 0))
                    }
                    editor.putString("widget_week", out.toString())
                }
            }
        } catch (e: Exception) {
            // Keep whatever was there; the app rewrites it when it next runs.
        }
        editor.putString("widget_day", today)
        editor.apply()
    }

    // ---- Actions from the widget (tick, water) ----

    private fun handleAction(context: Context, intent: Intent) {
        val kind = intent.getStringExtra("kind") ?: return
        val prefs = HomeWidgetPlugin.getData(context)
        rollOver(prefs)
        val day = str(prefs, "widget_day", todayKey())
        try {
            val pending = JSONArray(str(prefs, "widget_pending", "[]"))
            val kept = JSONArray()

            if (kind == "water") {
                val delta = intent.getIntExtra("delta", 0)
                if (delta == 0) return
                val current = intOf(prefs, "widget_water", 0)
                var next = current + delta
                if (next < 0) next = 0
                if (next > 30) next = 30
                val applied = next - current
                if (applied == 0) return
                var total = applied
                for (i in 0 until pending.length()) {
                    val p = pending.getJSONObject(i)
                    if (p.optString("k") == "water" && p.optString("day") == day) {
                        total += p.optInt("delta", 0)
                    } else {
                        kept.put(p)
                    }
                }
                if (total != 0) {
                    kept.put(
                        JSONObject().put("k", "water").put("delta", total).put("day", day))
                }
                prefs.edit()
                    .putString("widget_water", next.toString())
                    .putString("widget_pending", kept.toString())
                    .apply()
            } else {
                val key = intent.getStringExtra("key") ?: return
                val index = intent.getIntExtra("index", -1)
                val listKey = if (kind == "task") "widget_tasks" else "widget_habits"
                val arr = JSONArray(str(prefs, listKey, "[]"))
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

                // A later tap on the same item replaces the earlier one.
                for (i in 0 until pending.length()) {
                    val p = pending.getJSONObject(i)
                    val same = p.optString("k") == kind &&
                        p.optString("key") == key &&
                        p.optInt("i", -2) == index &&
                        p.optString("day") == day
                    if (!same) kept.put(p)
                }
                kept.put(
                    JSONObject()
                        .put("k", kind).put("key", key).put("i", index)
                        .put("v", newValue).put("day", day))
                prefs.edit()
                    .putString(listKey, arr.toString())
                    .putString("widget_pending", kept.toString())
                    .apply()
            }
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

    private fun actionIntent(
        context: Context, kind: String, key: String, index: Int, delta: Int
    ): PendingIntent {
        val intent = Intent(context, HabitsWidgetProvider::class.java)
        intent.action = ACTION_TOGGLE
        intent.data = Uri.parse(
            "prakriya://widget/action/$kind/$index/$delta/" + Uri.encode(key))
        intent.putExtra("kind", kind)
        intent.putExtra("key", key)
        intent.putExtra("index", index)
        intent.putExtra("delta", delta)
        return PendingIntent.getBroadcast(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    // ---- Drawing ----

    private fun build(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        data: SharedPreferences
    ): RemoteViews {
        rollOver(data)

        val base = palette(str(data, "widget_style", "dusk"))
        var accent = base.accent
        var titleColor = base.title
        val accentHex = str(data, "widget_accent", "")
        if (accentHex.isNotEmpty()) {
            try {
                accent = Color.parseColor(accentHex)
                titleColor = accent
            } catch (e: Exception) {
                // Keep the style's own colours.
            }
        }
        val p = base
        val pkg = context.packageName
        val density = context.resources.displayMetrics.density

        val sizeKey = str(data, "widget_text_size", "medium")
        val scale = if (sizeKey == "small") 0.9f else if (sizeKey == "large") 1.2f else 1.0f
        val compact = flag(data, "widget_compact", false)
        val opacity = intOf(data, "widget_opacity", 100).coerceIn(30, 100)
        val rowTapTicks = str(data, "widget_row_tap", "open") == "tick"
        val maxRows = intOf(data, "widget_max_rows", 0)
        val showDate = flag(data, "widget_show_date", true)
        val showDoneTasks = flag(data, "widget_show_done_tasks", true)

        val views = RemoteViews(pkg, R.layout.habits_widget)
        views.setImageViewResource(R.id.widget_bg, p.background)
        views.setInt(R.id.widget_bg, "setImageAlpha", (opacity * 255) / 100)

        // Usable height (dp). Portrait uses the maximum height the launcher
        // reports, landscape the minimum.
        val options = manager.getAppWidgetOptions(id)
        val portrait = context.resources.configuration.orientation == Configuration.ORIENTATION_PORTRAIT
        var height = options.getInt(
            if (portrait) AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT
            else AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        if (height <= 0) height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180)
        if (height <= 0) height = 180

        // Header
        val mode = str(data, "widget_title_mode", "app")
        val title = when (mode) {
            "greeting" -> greeting(str(data, "widget_user", ""))
            "day" -> "Today"
            else -> "Prakriyā"
        }
        views.setTextViewText(R.id.widget_title, title)
        views.setTextColor(R.id.widget_title, titleColor)
        views.setTextViewTextSize(R.id.widget_title, TypedValue.COMPLEX_UNIT_SP, 15f * scale)
        val dateLabel = str(data, "widget_date", "")
        if (showDate && dateLabel.isNotEmpty()) {
            views.setTextViewText(R.id.widget_date, dateLabel)
            views.setTextColor(R.id.widget_date, p.muted)
            views.setTextViewTextSize(R.id.widget_date, TypedValue.COMPLEX_UNIT_SP, 11f * scale)
            views.setViewVisibility(R.id.widget_date, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_date, View.GONE)
        }
        views.setTextColor(R.id.widget_add, accent)
        val openDash = openIntent(context, "dashboard")
        val openAdd = openIntent(context, "addtask")
        if (openDash != null) {
            views.setOnClickPendingIntent(R.id.widget_root, openDash)
            views.setOnClickPendingIntent(R.id.widget_head, openDash)
        }
        if (openAdd != null) views.setOnClickPendingIntent(R.id.widget_add, openAdd)

        var budget = height.toFloat() - 28f - (if (showDate) 36f else 22f) * scale - 10f

        // Data
        val tasks = readArray(data, "widget_tasks")
        val habits = readArray(data, "widget_habits")
        var tasksDone = 0
        for (i in 0 until tasks.length()) {
            if (tasks.getJSONObject(i).optBoolean("d", false)) tasksDone++
        }
        var habitsDone = 0
        for (i in 0 until habits.length()) {
            if (habits.getJSONObject(i).optBoolean("d", false)) habitsDone++
        }
        val rowBg = if (p.light) R.drawable.widget_row_bg_light else R.drawable.widget_row_bg_dark

        val blocks = readArray(data, "widget_blocks")
        views.removeAllViews(R.id.widget_content)

        for (b in 0 until blocks.length()) {
            when (blocks.optString(b)) {
                "stats" -> {
                    val cost = (20f + 11f) * 1.3f * scale + 10f
                    val stats = readArray(data, "widget_stats")
                    if (budget >= cost && stats.length() > 0) {
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
                                    value = if (habits.length() == 0) "–" else "$habitsDone/${habits.length()}"
                                } else if (kind == "tasks") {
                                    value = if (tasks.length() == 0) "–" else "$tasksDone/${tasks.length()}"
                                } else if (kind == "open") {
                                    value = (tasks.length() - tasksDone).toString()
                                }
                                child.setTextViewText(values[i], value)
                                child.setTextColor(values[i], p.text)
                                child.setTextViewTextSize(values[i], TypedValue.COMPLEX_UNIT_SP, 20f * scale)
                                child.setTextViewText(labels[i], s.optString("l", ""))
                                child.setTextColor(labels[i], p.muted)
                                child.setTextViewTextSize(labels[i], TypedValue.COMPLEX_UNIT_SP, 11f * scale)
                                child.setViewVisibility(cells[i], View.VISIBLE)
                            } else {
                                child.setViewVisibility(cells[i], View.GONE)
                            }
                        }
                        views.addView(R.id.widget_content, child)
                        budget -= cost
                    }
                }
                "progress" -> {
                    val total = habits.length() + tasks.length()
                    val cost = 12f * 1.3f * scale + 22f
                    if (budget >= cost && total > 0) {
                        val done = habitsDone + tasksDone
                        val filled = ((done * 10f) / total).let { Math.round(it) }
                        val child = RemoteViews(pkg, R.layout.widget_block_progress)
                        val segs = intArrayOf(
                            R.id.seg1, R.id.seg2, R.id.seg3, R.id.seg4, R.id.seg5,
                            R.id.seg6, R.id.seg7, R.id.seg8, R.id.seg9, R.id.seg10)
                        for (i in segs.indices) {
                            if (i < filled) {
                                child.setInt(segs[i], "setColorFilter", accent)
                                child.setInt(segs[i], "setImageAlpha", 255)
                            } else {
                                child.setInt(segs[i], "setColorFilter", p.muted)
                                child.setInt(segs[i], "setImageAlpha", 90)
                            }
                        }
                        child.setTextViewText(
                            R.id.progress_label,
                            if (done >= total) "Everything done today" else "$done of $total done today")
                        child.setTextColor(R.id.progress_label, p.muted)
                        child.setTextViewTextSize(R.id.progress_label, TypedValue.COMPLEX_UNIT_SP, 12f * scale)
                        views.addView(R.id.widget_content, child)
                        budget -= cost
                    }
                }
                "tasks" -> {
                    budget = addList(
                        context, views, p, accent, budget, scale, compact, density, rowBg,
                        "task", "TO-DO", tasks, showDoneTasks, maxRows, rowTapTicks,
                        "No tasks yet for today. Tap + to add one.")
                }
                "habits" -> {
                    budget = addList(
                        context, views, p, accent, budget, scale, compact, density, rowBg,
                        "habit", "HABITS", habits, true, maxRows, rowTapTicks,
                        "No habits selected. Pick some in the app.")
                }
                "water" -> {
                    val cost = 44f
                    if (budget >= cost) {
                        val goal = intOf(data, "widget_water_goal", 8)
                        val count = intOf(data, "widget_water", 0)
                        val child = RemoteViews(pkg, R.layout.widget_block_water)
                        child.setTextViewText(R.id.water_label, "Water  $count / $goal")
                        child.setTextColor(R.id.water_label, p.text)
                        child.setTextViewTextSize(R.id.water_label, TypedValue.COMPLEX_UNIT_SP, 14f * scale)
                        for (btn in intArrayOf(R.id.water_minus, R.id.water_plus)) {
                            child.setInt(btn, "setBackgroundResource", rowBg)
                            child.setTextColor(btn, accent)
                        }
                        child.setOnClickPendingIntent(
                            R.id.water_minus, actionIntent(context, "water", "water", -1, -1))
                        child.setOnClickPendingIntent(
                            R.id.water_plus, actionIntent(context, "water", "water", -1, 1))
                        views.addView(R.id.widget_content, child)
                        budget -= cost
                    }
                }
                "week" -> {
                    val cost = 11f * 1.3f * scale + 30f
                    val week = readArray(data, "widget_week")
                    if (budget >= cost && week.length() == 7) {
                        val child = RemoteViews(pkg, R.layout.widget_block_week)
                        val letters = intArrayOf(
                            R.id.wk_l1, R.id.wk_l2, R.id.wk_l3, R.id.wk_l4,
                            R.id.wk_l5, R.id.wk_l6, R.id.wk_l7)
                        val dots = intArrayOf(
                            R.id.wk_d1, R.id.wk_d2, R.id.wk_d3, R.id.wk_d4,
                            R.id.wk_d5, R.id.wk_d6, R.id.wk_d7)
                        for (i in 0 until 7) {
                            val d = week.getJSONObject(i)
                            val percent = d.optInt("p", 0)
                            child.setTextViewText(letters[i], d.optString("l", ""))
                            child.setTextColor(letters[i], if (i == 6) accent else p.muted)
                            child.setTextViewTextSize(letters[i], TypedValue.COMPLEX_UNIT_SP, 11f * scale)
                            if (percent <= 0) {
                                child.setInt(dots[i], "setColorFilter", p.muted)
                                child.setInt(dots[i], "setImageAlpha", 70)
                            } else if (percent < 100) {
                                child.setInt(dots[i], "setColorFilter", accent)
                                child.setInt(dots[i], "setImageAlpha", 150)
                            } else {
                                child.setInt(dots[i], "setColorFilter", accent)
                                child.setInt(dots[i], "setImageAlpha", 255)
                            }
                        }
                        views.addView(R.id.widget_content, child)
                        budget -= cost
                    }
                }
                "mantra" -> {
                    val mantra = str(data, "widget_mantra", "")
                    val cost = 13f * 1.3f * 2f * scale + 12f
                    if (mantra.isNotEmpty() && budget >= cost) {
                        val child = RemoteViews(pkg, R.layout.widget_block_text)
                        child.setTextViewText(R.id.text_body, "“$mantra”")
                        child.setTextColor(R.id.text_body, p.text)
                        child.setTextViewTextSize(R.id.text_body, TypedValue.COMPLEX_UNIT_SP, 13f * scale)
                        views.addView(R.id.widget_content, child)
                        budget -= cost
                    }
                }
            }
        }
        return views
    }

    private fun greeting(name: String): String {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        val part = if (hour < 12) "Good morning" else if (hour < 17) "Good afternoon" else "Good evening"
        return if (name.trim().isEmpty()) part else part + ", " + name.trim()
    }

    /**
     * Adds a titled list (tasks or habits) as far as the remaining height
     * allows and returns the height left over.
     */
    private fun addList(
        context: Context,
        views: RemoteViews,
        p: Palette,
        accent: Int,
        budgetIn: Float,
        scale: Float,
        compact: Boolean,
        density: Float,
        rowBg: Int,
        kind: String,
        title: String,
        items: JSONArray,
        showDone: Boolean,
        maxRows: Int,
        rowTapTicks: Boolean,
        emptyText: String
    ): Float {
        var budget = budgetIn
        val pkg = context.packageName
        val textSp = 14f * scale
        val padDp = if (compact) 3f else 6f
        val rowCost = textSp * 1.4f + padDp * 2f + 6f
        val headerCost = 12f * 1.3f * scale + 12f
        if (budget < headerCost + rowCost) return budget

        val open = openIntent(context, if (kind == "task") "tasks" else "dashboard")

        val rows = ArrayList<JSONObject>()
        var doneCount = 0
        for (i in 0 until items.length()) {
            val o = items.getJSONObject(i)
            if (o.optBoolean("d", false)) doneCount++
            if (showDone || !o.optBoolean("d", false)) rows.add(o)
        }

        // How many rows fit, and how many the user allows.
        var fit = ((budget - headerCost) / rowCost).toInt()
        if (maxRows > 0 && fit > maxRows) fit = maxRows
        val shown = if (rows.size < fit) rows.size else fit
        val hidden = rows.size - shown

        val header = RemoteViews(pkg, R.layout.widget_block_header)
        header.setTextViewText(R.id.hdr_text, title)
        header.setTextColor(R.id.hdr_text, accent)
        header.setTextViewTextSize(R.id.hdr_text, TypedValue.COMPLEX_UNIT_SP, 12f * scale)
        var count = if (items.length() == 0) "" else "$doneCount/${items.length()}"
        if (hidden > 0) count = if (count.isEmpty()) "+$hidden more" else "$count · +$hidden more"
        header.setTextViewText(R.id.hdr_count, count)
        header.setTextColor(R.id.hdr_count, p.muted)
        header.setTextViewTextSize(R.id.hdr_count, TypedValue.COMPLEX_UNIT_SP, 12f * scale)
        if (open != null) {
            header.setOnClickPendingIntent(R.id.hdr_text, open)
            header.setOnClickPendingIntent(R.id.hdr_count, open)
        }
        views.addView(R.id.widget_content, header)
        budget -= headerCost

        if (rows.isEmpty()) {
            val note = RemoteViews(pkg, R.layout.widget_block_text)
            val text = if (items.length() == 0) emptyText else "All done. Nicely done."
            note.setTextViewText(R.id.text_body, text)
            note.setTextColor(R.id.text_body, p.muted)
            note.setTextViewTextSize(R.id.text_body, TypedValue.COMPLEX_UNIT_SP, 13f * scale)
            if (open != null) note.setOnClickPendingIntent(R.id.text_body, open)
            views.addView(R.id.widget_content, note)
            return budget - (13f * 1.3f * 2f * scale + 10f)
        }

        val padPx = (padDp * density).toInt()
        val sidePx = (10f * density).toInt()
        for (n in 0 until shown) {
            val o = rows[n]
            val row = RemoteViews(pkg, R.layout.widget_row)
            val done = o.optBoolean("d", false)
            val name = if (kind == "task") o.optString("t") else o.optString("n")
            val key = if (kind == "task") o.optString("t") else o.optString("id")
            val index = if (kind == "task") o.optInt("i", -1) else -1
            row.setInt(R.id.row_root, "setBackgroundResource", rowBg)
            row.setViewPadding(R.id.row_root, sidePx, padPx, sidePx, padPx)
            row.setTextViewText(R.id.row_text, name)
            row.setTextColor(R.id.row_text, if (done) p.done else p.text)
            row.setTextViewTextSize(R.id.row_text, TypedValue.COMPLEX_UNIT_SP, textSp)
            row.setImageViewResource(
                R.id.row_mark, if (done) R.drawable.widget_check_on else R.drawable.widget_check_off)
            row.setInt(R.id.row_mark, "setColorFilter", if (done) p.done else accent)
            val tick = actionIntent(context, kind, key, index, 0)
            row.setOnClickPendingIntent(R.id.row_mark, tick)
            if (rowTapTicks) {
                row.setOnClickPendingIntent(R.id.row_text, tick)
            } else if (open != null) {
                row.setOnClickPendingIntent(R.id.row_text, open)
            }
            views.addView(R.id.widget_content, row)
            budget -= rowCost
        }
        return budget
    }
}
