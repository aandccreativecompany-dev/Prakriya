package ai.aandccreative.prakriya

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/**
 * Prakriyā home-screen widget. All content and the chosen look ("style") are
 * written by the Flutter side (HomeWidgetService) into shared preferences;
 * this class only turns them into RemoteViews. It adapts to the widget's
 * current height so a short widget shows less instead of clipping.
 */
class HabitsWidgetProvider : HomeWidgetProvider() {

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

    private fun build(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        data: SharedPreferences
    ): RemoteViews {
        val p = palette(data.getString("widget_style", "dusk"))
        val views = RemoteViews(context.packageName, R.layout.habits_widget)

        // Height budget (dp): decides how much fits.
        val options = manager.getAppWidgetOptions(id)
        var height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
        if (height <= 0) height = 110

        val mantra = data.getString("widget_mantra", "") ?: ""
        val priority = data.getString("widget_top_priority", "") ?: ""
        // Everything is stored as text by the Flutter side, so reads never
        // depend on how the platform channel boxed a number.
        val showProgress = (data.getString("widget_show_progress", "1") ?: "1") == "1"
        val showStreak = (data.getString("widget_show_streak", "1") ?: "1") == "1"
        val streak = (data.getString("widget_streak", "0") ?: "0").toIntOrNull() ?: 0
        val done = (data.getString("widget_done", "0") ?: "0").toIntOrNull() ?: 0
        val total = (data.getString("widget_total", "0") ?: "0").toIntOrNull() ?: 0
        val dateLabel = data.getString("widget_date", "") ?: ""
        val habits = parseHabits(data.getString("widget_habits", "[]"))

        views.setInt(R.id.widget_root, "setBackgroundResource", p.background)

        // Header
        views.setTextViewText(R.id.widget_title, "Prakriyā")
        views.setTextColor(R.id.widget_title, p.title)
        if (showStreak && streak > 0) {
            views.setTextViewText(R.id.widget_streak, "🔥 $streak")
            views.setTextColor(R.id.widget_streak, p.accent)
            views.setViewVisibility(R.id.widget_streak, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_streak, View.GONE)
        }
        views.setTextViewText(R.id.widget_date, dateLabel)
        views.setTextColor(R.id.widget_date, p.muted)
        views.setViewVisibility(R.id.widget_date, if (dateLabel.isEmpty()) View.GONE else View.VISIBLE)

        var budget = height - 28 - 30 // padding + header

        // Progress (always worth showing when there are habits)
        val progressVisible = showProgress && total > 0 && budget >= 28
        val barIds = mapOf(
            "dusk" to R.id.widget_progress_dusk,
            "sunrise" to R.id.widget_progress_sunrise,
            "forest" to R.id.widget_progress_forest,
            "paper" to R.id.widget_progress_paper
        )
        for ((key, barId) in barIds) {
            views.setViewVisibility(
                barId, if (progressVisible && key == p.key) View.VISIBLE else View.GONE)
        }
        if (progressVisible) {
            val pct = if (total == 0) 0 else (done * 100) / total
            val barId = barIds[p.key] ?: R.id.widget_progress_dusk
            views.setProgressBar(barId, 100, pct, false)
            views.setTextViewText(
                R.id.widget_progress_label,
                if (done >= total) "All $total habits done today ✓" else "$done of $total habits done")
            views.setTextColor(R.id.widget_progress_label, p.muted)
            views.setViewVisibility(R.id.widget_progress_label, View.VISIBLE)
            budget -= 28
        } else {
            views.setViewVisibility(R.id.widget_progress_label, View.GONE)
        }

        // Priority
        if (priority.isNotEmpty() && budget >= 22) {
            views.setTextViewText(R.id.widget_priority, "▸ $priority")
            views.setTextColor(R.id.widget_priority, p.text)
            views.setViewVisibility(R.id.widget_priority, View.VISIBLE)
            budget -= 24
        } else {
            views.setViewVisibility(R.id.widget_priority, View.GONE)
        }

        // Habit rows
        val rowIds = intArrayOf(
            R.id.widget_h1, R.id.widget_h2, R.id.widget_h3, R.id.widget_h4, R.id.widget_h5)
        for (i in rowIds.indices) {
            if (i < habits.size && budget >= 20) {
                val h = habits[i]
                val mark = if (h.second) "✓  " else "○  "
                views.setTextViewText(rowIds[i], mark + h.first)
                views.setTextColor(rowIds[i], if (h.second) p.done else p.text)
                views.setViewVisibility(rowIds[i], View.VISIBLE)
                budget -= 20
            } else {
                views.setViewVisibility(rowIds[i], View.GONE)
            }
        }

        // Mantra goes last: it is the first thing to drop when space is tight.
        if (mantra.isNotEmpty() && budget >= 34) {
            views.setTextViewText(R.id.widget_mantra, "“$mantra”")
            views.setTextColor(R.id.widget_mantra, p.text)
            views.setViewVisibility(R.id.widget_mantra, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_mantra, View.GONE)
        }

        val nothing = mantra.isEmpty() && priority.isEmpty() && habits.isEmpty()
        views.setTextColor(R.id.widget_empty, p.muted)
        views.setViewVisibility(R.id.widget_empty, if (nothing) View.VISIBLE else View.GONE)

        // Tap anywhere to open the app.
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launch != null) {
            val pending = PendingIntent.getActivity(
                context, 0, launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_root, pending)
        }
        return views
    }

    private fun parseHabits(raw: String?): List<Pair<String, Boolean>> {
        val out = ArrayList<Pair<String, Boolean>>()
        if (raw.isNullOrEmpty()) return out
        try {
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                out.add(Pair(o.optString("name", ""), o.optBoolean("done", false)))
            }
        } catch (e: Exception) {
            // Malformed data: show nothing rather than crash the launcher.
        }
        return out
    }
}
