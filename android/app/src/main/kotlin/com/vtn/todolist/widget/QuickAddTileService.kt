package com.vtn.todolist.widget

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.vtn.todolist.MainActivity
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/** Quick Settings tile: pull down the shade, tap, type a task */
class QuickAddTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        qsTile?.apply {
            state = Tile.STATE_INACTIVE
            updateTile()
        }
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    override fun onClick() {
        super.onClick()
        val uri = link("quickadd?homeWidget")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(
                HomeWidgetLaunchIntent.getActivity(this, MainActivity::class.java, uri),
            )
        } else {
            val intent = Intent(this, MainActivity::class.java).apply {
                action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                data = uri
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
