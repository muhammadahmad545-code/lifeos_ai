package dev.basalt.lifeos

import android.app.StatusBarManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts Flutter (FragmentActivity is required by local_auth for the optional app lock) and a
 * small "quick access" channel: launcher shortcuts, the New task tile's action and the
 * "Today" home-screen widget's data.
 */
class MainActivity : FlutterFragmentActivity() {
  private var channel: MethodChannel? = null
  private var pendingAction: String? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    pendingAction = takeActionFrom(intent)
    channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
      setMethodCallHandler { call, result ->
        when (call.method) {
          "takeAction" -> {
            result.success(pendingAction)
            pendingAction = null
          }
          "installShortcuts" -> result.success(installShortcuts())
          "updateWidget" -> {
            TodayWidget.save(this@MainActivity, call.argument<String>("json") ?: "{}")
            result.success(null)
          }
          "pinWidget" -> result.success(pinWidget())
          "addTile" -> result.success(addTile())
          else -> result.notImplemented()
        }
      }
    }
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    val action = takeActionFrom(intent) ?: return
    setIntent(intent)
    val ch = channel
    if (ch == null) pendingAction = action else ch.invokeMethod("action", action)
  }

  /** Reads the action once, so a configuration change does not open the editor again. */
  private fun takeActionFrom(intent: Intent?): String? {
    val action = intent?.getStringExtra(EXTRA_ACTION) ?: return null
    intent.removeExtra(EXTRA_ACTION)
    return action
  }

  private fun installShortcuts(): Boolean {
    if (Build.VERSION.SDK_INT < 25) return false
    val manager = getSystemService(ShortcutManager::class.java) ?: return false
    fun shortcut(id: String, label: String, long: String, icon: Int) = ShortcutInfo.Builder(this, id)
      .setShortLabel(label)
      .setLongLabel(long)
      .setIcon(Icon.createWithResource(this, icon))
      .setIntent(actionIntent(this, id).setAction(Intent.ACTION_MAIN))
      .build()
    return runCatching {
      manager.dynamicShortcuts = listOf(
        shortcut(ACTION_NEW_TASK, "New task", "Add a new task", R.drawable.ic_shortcut_task),
        shortcut(ACTION_NEW_NOTE, "New note", "Write a new note", R.drawable.ic_shortcut_note),
        shortcut(ACTION_FOCUS, "Start focus", "Start a focus session", R.drawable.ic_shortcut_focus),
      )
      true
    }.getOrDefault(false)
  }

  private fun pinWidget(): Boolean {
    if (Build.VERSION.SDK_INT < 26) return false
    val manager = AppWidgetManager.getInstance(this)
    if (!manager.isRequestPinAppWidgetSupported) return false
    return runCatching { manager.requestPinAppWidget(ComponentName(this, TodayWidget::class.java), null, null) }.getOrDefault(false)
  }

  private fun addTile(): Boolean {
    if (Build.VERSION.SDK_INT < 33) return false
    val manager = getSystemService(StatusBarManager::class.java) ?: return false
    return runCatching {
      manager.requestAddTileService(
        ComponentName(this, NewTaskTileService::class.java),
        "New task",
        Icon.createWithResource(this, R.drawable.ic_tile_task),
        mainExecutor,
      ) { }
      true
    }.getOrDefault(false)
  }

  companion object {
    const val CHANNEL = "dev.basalt.plania/quick"
    const val EXTRA_ACTION = "plania.action"
    const val ACTION_NEW_TASK = "new-task"
    const val ACTION_NEW_NOTE = "new-note"
    const val ACTION_FOCUS = "focus"

    fun actionIntent(context: android.content.Context, action: String): Intent =
      Intent(context, MainActivity::class.java)
        .putExtra(EXTRA_ACTION, action)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
  }
}
