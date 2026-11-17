package com.vtn.todolist.widget

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import com.vtn.todolist.MainActivity
import com.vtn.todolist.R
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.actionStartActivity

/** The app's colour tokens (light / dark), so the widget matches it */
internal object WidgetColors {
    val card = ColorProvider(day = Color(0xFFFFFFFF), night = Color(0xFF152321))
    val primary = ColorProvider(day = Color(0xFF0F766E), night = Color(0xFF5EEAD4))
    val primarySoft = ColorProvider(day = Color(0xFFD7F5EE), night = Color(0xFF1B3A36))
    val text = ColorProvider(day = Color(0xFF134E4A), night = Color(0xFFE6F2F0))
    val muted = ColorProvider(day = Color(0xFF475569), night = Color(0xFFA3B8B5))
    val outline = ColorProvider(day = Color(0xFF64748B), night = Color(0xFF7B918E))

    fun priority(p: Int) = when (p) {
        1 -> ColorProvider(day = Color(0xFF2563EB), night = Color(0xFF60A5FA))
        2 -> ColorProvider(day = Color(0xFF92590A), night = Color(0xFFFBBF24))
        3 -> ColorProvider(day = Color(0xFFC2410C), night = Color(0xFFFB923C))
        else -> outline
    }
}

internal fun link(path: String): Uri = Uri.parse("todolist://$path")

/** Today's open tasks; tick to complete, "+" to add */
class TodayWidget : GlanceAppWidget() {

    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val prefs = currentState<HomeWidgetGlanceState>().preferences
            TodayContent(context, TodaySnapshot.parse(prefs.getString(TodaySnapshot.KEY, null)))
        }
    }

    override suspend fun providePreview(context: Context, widgetCategory: Int) {
        provideContent {
            val prefs = HomeWidgetPlugin.getData(context)
            TodayContent(context, TodaySnapshot.parse(prefs.getString(TodaySnapshot.KEY, null)))
        }
    }
}

@Composable
private fun TodayContent(context: Context, snapshot: TodaySnapshot?) {
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .appWidgetBackground()
            .background(WidgetColors.card)
            .cornerRadius(20.dp)
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(
                modifier = GlanceModifier
                    .defaultWeight()
                    .clickable(actionStartActivity<MainActivity>(context, link("today?homeWidget"))),
            ) {
                Text(
                    text = snapshot?.label("title") ?: context.getString(R.string.widget_today_name),
                    style = TextStyle(
                        color = WidgetColors.primary,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                    maxLines = 1,
                )
                val subtitle = snapshot?.leftLabel.orEmpty()
                if (subtitle.isNotEmpty()) {
                    Text(
                        text = subtitle,
                        style = TextStyle(color = WidgetColors.muted, fontSize = 12.sp),
                        maxLines = 1,
                    )
                }
            }
            AddButton(context, snapshot?.label("add").orEmpty())
        }
        Spacer(GlanceModifier.height(6.dp))
        val items = snapshot?.items.orEmpty()
        if (items.isEmpty()) {
            Box(
                modifier = GlanceModifier
                    .fillMaxSize()
                    .clickable(actionStartActivity<MainActivity>(context, link("today?homeWidget"))),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = when {
                        snapshot == null -> context.getString(R.string.widget_today_name)
                        snapshot.done > 0 -> snapshot.label("allDone")
                        else -> snapshot.label("empty")
                    },
                    style = TextStyle(
                        color = WidgetColors.muted,
                        fontSize = 13.sp,
                        textAlign = TextAlign.Center,
                    ),
                )
            }
        } else {
            LazyColumn(modifier = GlanceModifier.fillMaxSize()) {
                items(items, itemId = { it.id.hashCode().toLong() }) { item ->
                    TaskRow(context, item, snapshot?.label("check").orEmpty())
                }
            }
        }
    }
}

@Composable
private fun TaskRow(context: Context, item: TodaySnapshot.Item, checkLabel: String) {
    Row(
        modifier = GlanceModifier.fillMaxWidth().padding(vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // 40dp touch target around a 20dp ring
        Box(
            modifier = GlanceModifier
                .size(40.dp)
                .clickable(
                    actionRunCallback<CompleteTaskAction>(
                        actionParametersOf(CompleteTaskAction.taskId to item.id),
                    ),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Image(
                provider = ImageProvider(R.drawable.widget_check_ring),
                contentDescription = "$checkLabel: ${item.title}",
                colorFilter = ColorFilter.tint(WidgetColors.priority(item.priority)),
                modifier = GlanceModifier.size(20.dp),
            )
        }
        Row(
            modifier = GlanceModifier
                .defaultWeight()
                .clickable(
                    actionStartActivity<MainActivity>(
                        context,
                        link("task?id=${Uri.encode(item.id)}&homeWidget"),
                    ),
                ),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = item.title,
                style = TextStyle(
                    color = if (item.late) WidgetColors.muted else WidgetColors.text,
                    fontSize = 14.sp,
                ),
                maxLines = 1,
                modifier = GlanceModifier.defaultWeight(),
            )
            item.time?.let {
                Spacer(GlanceModifier.width(6.dp))
                Text(
                    text = it,
                    style = TextStyle(color = WidgetColors.muted, fontSize = 12.sp),
                    maxLines = 1,
                )
            }
        }
    }
}

@Composable
internal fun AddButton(context: Context, label: String) {
    Box(
        modifier = GlanceModifier
            .size(40.dp)
            .cornerRadius(20.dp)
            .background(WidgetColors.primarySoft)
            .clickable(actionStartActivity<MainActivity>(context, link("quickadd?homeWidget"))),
        contentAlignment = Alignment.Center,
    ) {
        Image(
            provider = ImageProvider(R.drawable.widget_add),
            contentDescription = label.ifEmpty { context.getString(R.string.quick_add_label) },
            colorFilter = ColorFilter.tint(WidgetColors.primary),
            modifier = GlanceModifier.size(22.dp),
        )
    }
}

/**
 * Ticked on the widget: drop the row now, then let the app's background
 * isolate complete the task, update reminders and rewrite the snapshot.
 */
class CompleteTaskAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        val id = parameters[taskId] ?: return
        TodaySnapshot.markDone(HomeWidgetPlugin.getData(context), id)
        TodayWidget().updateAll(context)
        HomeWidgetBackgroundIntent.getBroadcast(
            context,
            link("complete?id=${Uri.encode(id)}"),
        ).send()
    }

    companion object {
        val taskId = ActionParameters.Key<String>("taskId")
    }
}

class TodayWidgetReceiver : HomeWidgetGlanceWidgetReceiver<TodayWidget>() {
    override val glanceAppWidget = TodayWidget()
}
