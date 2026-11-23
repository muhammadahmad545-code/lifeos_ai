package dev.basalt.lifeos

import android.app.PendingIntent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/** Quick Settings tile: opens Plania straight into the new-task editor. */
class NewTaskTileService : TileService() {
  override fun onStartListening() {
    val tile = qsTile ?: return
    tile.label = "New task"
    tile.state = Tile.STATE_INACTIVE
    if (Build.VERSION.SDK_INT >= 29) tile.subtitle = "Plania"
    tile.updateTile()
  }

  override fun onClick() {
    val intent = MainActivity.actionIntent(this, MainActivity.ACTION_NEW_TASK)
    if (Build.VERSION.SDK_INT >= 34) {
      startActivityAndCollapse(PendingIntent.getActivity(this, 41, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
    } else {
      @Suppress("DEPRECATION")
      startActivityAndCollapse(intent)
    }
  }
}
