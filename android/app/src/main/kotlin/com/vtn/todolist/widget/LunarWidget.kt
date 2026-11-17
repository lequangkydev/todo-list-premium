package com.vtn.todolist.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
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
import java.time.LocalDate
import org.json.JSONObject

/**
 * One day of the lunar table the app writes (Dart `LunarWidgetSnapshot`):
 * every label already translated.
 */
data class LunarDay(
    val day: Int,
    val weekday: String,
    val month: String,
    val lunar: String,
    val festival: String?,
    val year: String?,
) {
    companion object {
        const val KEY = "lunar_snapshot"

        /** Today's row, or null when the table doesn't reach today */
        fun today(json: String?, date: LocalDate = LocalDate.now()): LunarDay? {
            if (json.isNullOrEmpty()) return null
            return try {
                val row = JSONObject(json).optJSONObject("days")?.optJSONObject(date.toString())
                    ?: return null
                LunarDay(
                    day = row.optInt("d", date.dayOfMonth),
                    weekday = row.optString("w"),
                    month = row.optString("m"),
                    lunar = row.optString("l"),
                    festival = if (row.has("f")) row.optString("f") else null,
                    year = if (row.has("y")) row.optString("y") else null,
                )
            } catch (e: Exception) {
                null
            }
        }
    }
}

/** Today's date with its lunar date, festival and year name */
class LunarWidget : GlanceAppWidget() {

    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val prefs = currentState<HomeWidgetGlanceState>().preferences
            LunarContent(context, LunarDay.today(prefs.getString(LunarDay.KEY, null)))
        }
    }
}

private val festivalColor =
    ColorProvider(day = Color(0xFFC2410C), night = Color(0xFFFB923C))

@Composable
private fun LunarContent(context: Context, today: LunarDay?) {
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .appWidgetBackground()
            .background(WidgetColors.card)
            .cornerRadius(20.dp)
            .padding(10.dp)
            .clickable(actionStartActivity<MainActivity>(context, link("today?homeWidget"))),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (today == null) {
            // The app hasn't written the table yet (or not for months):
            // still show the date, and what opening the app will add
            Text(
                text = LocalDate.now().dayOfMonth.toString(),
                style = TextStyle(
                    color = WidgetColors.primary,
                    fontSize = 40.sp,
                    fontWeight = FontWeight.Bold,
                ),
            )
            Text(
                text = context.getString(R.string.widget_lunar_name),
                style = TextStyle(color = WidgetColors.muted, fontSize = 12.sp),
                maxLines = 1,
            )
        } else {
            LunarDayContent(today)
        }
    }
}

@Composable
private fun LunarDayContent(today: LunarDay) {
    Text(
        text = today.weekday,
        style = TextStyle(color = WidgetColors.muted, fontSize = 12.sp),
        maxLines = 1,
    )
    Text(
        text = today.day.toString(),
        style = TextStyle(
            color = WidgetColors.primary,
            fontSize = 40.sp,
            fontWeight = FontWeight.Bold,
        ),
    )
    Text(
        text = today.month,
        style = TextStyle(color = WidgetColors.muted, fontSize = 12.sp),
        maxLines = 1,
    )
    Spacer(GlanceModifier.height(4.dp))
    Text(
        text = today.lunar,
        style = TextStyle(
            color = WidgetColors.text,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Center,
        ),
        maxLines = 1,
    )
    val festival = today.festival
    if (festival != null) {
        Text(
            text = festival,
            style = TextStyle(
                color = festivalColor,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
            ),
            maxLines = 1,
        )
    } else if (today.year != null) {
        Text(
            text = today.year,
            style = TextStyle(color = WidgetColors.muted, fontSize = 11.sp),
            maxLines = 1,
        )
    }
}

class LunarWidgetReceiver : HomeWidgetGlanceWidgetReceiver<LunarWidget>() {
    override val glanceAppWidget = LunarWidget()
}
