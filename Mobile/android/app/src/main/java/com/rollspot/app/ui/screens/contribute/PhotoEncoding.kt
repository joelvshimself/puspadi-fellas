package com.rollspot.app.ui.screens.contribute

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream

/** Longest side of an uploaded review photo: plenty for a phone screen, well under the 10 MB API limit. */
private const val MAX_PHOTO_SIDE = 2048

/**
 * Turns a picked image into upload-ready JPEG bytes, off the main thread. Returns null when the
 * file can't be read or decoded (HEIC from some cameras, cloud files that failed to download).
 */
suspend fun jpegForUpload(context: Context, uri: Uri): ByteArray? = withContext(Dispatchers.IO) {
    runCatching {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return@runCatching null

        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= MAX_PHOTO_SIDE) sample *= 2
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        val bitmap: Bitmap = context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, options) }
            ?: return@runCatching null

        ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 80, out)
            bitmap.recycle()
            out.toByteArray()
        }
    }.getOrNull()
}
