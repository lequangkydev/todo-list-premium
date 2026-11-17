package com.vtn.todolist.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import com.vtn.todolist.MainActivity
import com.vtn.todolist.R
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import es.antonborri.home_widget.actionStartActivity

/** One tap from the home screen to the quick-add sheet */
class QuickAddWidget : GlanceAppWidget() {

    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val prefs = currentState<HomeWidgetGlanceState>().preferences
            val snapshot = TodaySnapshot.parse(prefs.getString(TodaySnapshot.KEY, null))
            QuickAddContent(context, snapshot?.label("add").orEmpty())
        }
    }
}

@Composable
private fun QuickAddContent(context: Context, label: String) {
    val text = label.ifEmpty { context.getString(R.string.quick_add_label) }
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .appWidgetBackground()
            .background(WidgetColors.card)
            .cornerRadius(20.dp)
            .padding(8.dp)
            .clickable(actionStartActivity<MainActivity>(context, link("quickadd?homeWidget"))),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = GlanceModifier
                .size(44.dp)
                .cornerRadius(22.dp)
                .background(WidgetColors.primary),
            contentAlignment = Alignment.Center,
        ) {
            Image(
                provider = ImageProvider(R.drawable.widget_add),
                contentDescription = text,
                colorFilter = ColorFilter.tint(WidgetColors.card),
                modifier = GlanceModifier.size(24.dp),
            )
        }
        Spacer(GlanceModifier.height(6.dp))
        Text(
            text = text,
            style = TextStyle(
                color = WidgetColors.text,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
            ),
            maxLines = 2,
        )
    }
}

class QuickAddWidgetReceiver : HomeWidgetGlanceWidgetReceiver<QuickAddWidget>() {
    override val glanceAppWidget = QuickAddWidget()
}
