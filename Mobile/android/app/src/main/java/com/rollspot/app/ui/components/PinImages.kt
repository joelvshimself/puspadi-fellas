package com.rollspot.app.ui.components

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import androidx.compose.ui.graphics.toArgb
import app.rollspot.shared.places.OverallAccessibility
import com.rollspot.app.ui.theme.color

/**
 * The map pin from the design: a grade-colored disc with a white ring and a
 * glyph (check / exclamation / cross). Drawn in code so it needs no assets.
 */
internal fun pinBitmap(grade: OverallAccessibility, density: Float): Bitmap {
    val size = (34 * density).toInt()
    val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val c = size / 2f
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)

    paint.color = 0x33000000 // soft shadow
    canvas.drawCircle(c, c + density, c - density, paint)
    paint.color = android.graphics.Color.WHITE
    canvas.drawCircle(c, c, c - density * 1.5f, paint)
    paint.color = grade.color.toArgb()
    canvas.drawCircle(c, c, c - density * 3.5f, paint)

    paint.color = android.graphics.Color.WHITE
    paint.style = Paint.Style.STROKE
    paint.strokeWidth = 2.6f * density
    paint.strokeCap = Paint.Cap.ROUND
    paint.strokeJoin = Paint.Join.ROUND
    fun x(f: Float) = size * f
    when (grade) {
        OverallAccessibility.ACCESSIBLE -> {
            canvas.drawLine(x(0.31f), x(0.52f), x(0.44f), x(0.65f), paint)
            canvas.drawLine(x(0.44f), x(0.65f), x(0.70f), x(0.36f), paint)
        }
        OverallAccessibility.PARTIALLY_ACCESSIBLE -> {
            canvas.drawLine(x(0.5f), x(0.29f), x(0.5f), x(0.54f), paint)
            paint.style = Paint.Style.FILL
            canvas.drawCircle(x(0.5f), x(0.69f), 1.6f * density, paint)
        }
        OverallAccessibility.NOT_ACCESSIBLE -> {
            canvas.drawLine(x(0.35f), x(0.35f), x(0.65f), x(0.65f), paint)
            canvas.drawLine(x(0.65f), x(0.35f), x(0.35f), x(0.65f), paint)
        }
        OverallAccessibility.NO_DATA -> Unit
    }
    return bitmap
}

internal val OverallAccessibility.pinImageId: String get() = "pin-${name.lowercase()}"
