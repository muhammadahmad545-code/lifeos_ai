package dev.basalt.lifeos

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.text.format.DateFormat
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * "Today" home-screen widget: tasks due today (and the first three titles), habits done out of
 * the total, and the next calendar event. The app sends a snapshot for today and tomorrow
 * whenever its data changes; the widget re-renders itself at midnight and when the shown event
 * ends, so it stays right without the app running. Tapping it opens Plania.
 */
class TodayWidget : AppWidgetProvider() {
  override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
    refresh(context)
  }

  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action == ACTION_TICK) refresh(context) else super.onReceive(context, intent)
  }

  override fun onDisabled(context: Context) {
    (context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager)?.cancel(tickIntent(context))
  }

  companion object {
    private const val PREFS = "plania_widget"
    private const val ACTION_TICK = "dev.basalt.lifeos.WIDGET_TICK"

    fun save(context: Context, json: String) {
      context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("data", json).apply()
      refresh(context)
    }

    fun refresh(context: Context) {
      val manager = AppWidgetManager.getInstance(context)
      val ids = manager.getAppWidgetIds(ComponentName(context, TodayWidget::class.java))
      if (ids.isEmpty()) return
      val now = System.currentTimeMillis()
      val (views, nextChange) = render(context, now)
      ids.forEach { manager.updateAppWidget(it, views) }
      schedule(context, nextChange)
    }

    private fun tickIntent(context: Context): PendingIntent =
      PendingIntent.getBroadcast(
        context, 51,
        Intent(context, TodayWidget::class.java).setAction(ACTION_TICK),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
      )

    /** An inexact alarm is enough here and needs no permission. */
    private fun schedule(context: Context, at: Long) {
      val alarms = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
      runCatching { alarms.set(AlarmManager.RTC, at, tickIntent(context)) }
    }

    private fun dayKey(millis: Long): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(millis))

    private fun nextMidnight(now: Long): Long = Calendar.getInstance().apply {
      timeInMillis = now
      add(Calendar.DAY_OF_YEAR, 1)
      set(Calendar.HOUR_OF_DAY, 0)
      set(Calendar.MINUTE, 0)
      set(Calendar.SECOND, 5)
      set(Calendar.MILLISECOND, 0)
    }.timeInMillis

    private fun sameDay(a: Long, b: Long) = dayKey(a) == dayKey(b)

    private fun render(context: Context, now: Long): Pair<RemoteViews, Long> {
      val data = runCatching {
        JSONObject(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("data", "{}") ?: "{}")
      }.getOrDefault(JSONObject())
      val v = RemoteViews(context.packageName, R.layout.today_widget)
      var nextChange = nextMidnight(now)

      v.setTextViewText(R.id.widget_date, SimpleDateFormat("EEE, MMM d", Locale.getDefault()).format(Date(now)))
      val day = data.optJSONObject("days")?.optJSONObject(dayKey(now))
      val titleIds = intArrayOf(R.id.widget_task1, R.id.widget_task2, R.id.widget_task3)
      if (day == null) {
        // No snapshot for today: Plania has not been opened for a while.
        v.setTextViewText(R.id.widget_tasks, "–")
        v.setTextViewText(R.id.widget_tasks_label, "Open Plania to refresh")
        v.setTextViewText(R.id.widget_habits, "–")
        titleIds.forEach { v.setViewVisibility(it, View.GONE) }
      } else {
        val count = day.optInt("tasks", 0)
        v.setTextViewText(R.id.widget_tasks, count.toString())
        v.setTextViewText(R.id.widget_tasks_label, if (count == 1) "task due today" else "tasks due today")
        val total = data.optInt("habitsTotal", 0)
        v.setTextViewText(R.id.widget_habits, if (total == 0) "–" else "${day.optInt("habitsDone", 0)}/$total")
        val titles = day.optJSONArray("titles")
        titleIds.forEachIndexed { i, id ->
          val t = titles?.optString(i, "")?.takeIf { it.isNotBlank() }
          if (t == null) {
            v.setViewVisibility(id, View.GONE)
          } else {
            v.setTextViewText(id, "•  $t")
            v.setViewVisibility(id, View.VISIBLE)
          }
        }
        if (count == 0) {
          v.setTextViewText(R.id.widget_task1, "Nothing due. Enjoy the day.")
          v.setViewVisibility(R.id.widget_task1, View.VISIBLE)
        }
      }

      // The first event that has not ended yet.
      val events = data.optJSONArray("events")
      var eventText = "No upcoming events"
      if (events != null) {
        for (i in 0 until events.length()) {
          val e = events.optJSONObject(i) ?: continue
          val start = e.optLong("start")
          val end = e.optLong("end")
          if (end <= now) continue
          val title = e.optString("title", "").ifBlank { "Event" }
          val time = DateFormat.getTimeFormat(context).format(Date(start))
          val whenText = when {
            e.optBoolean("allDay") && start <= now -> "Today"
            start <= now -> "Now"
            sameDay(start, now) -> if (e.optBoolean("allDay")) "Today" else time
            sameDay(start, nextMidnight(now)) -> if (e.optBoolean("allDay")) "Tomorrow" else "Tomorrow $time"
            else -> SimpleDateFormat("EEE, MMM d", Locale.getDefault()).format(Date(start)) +
              if (e.optBoolean("allDay")) "" else " $time"
          }
          eventText = "$whenText  ·  $title"
          // Re-render when it starts (to say "Now") or ends (to move to the next one).
          val change = if (start > now) start else end
          if (change in (now + 1) until nextChange) nextChange = change + 1000
          break
        }
      }
      v.setTextViewText(R.id.widget_event, eventText)

      val open = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
      v.setOnClickPendingIntent(R.id.widget_root, PendingIntent.getActivity(context, 50, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
      return v to nextChange
    }
  }
}
