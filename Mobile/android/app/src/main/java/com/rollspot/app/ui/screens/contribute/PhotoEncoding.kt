package com.rollspot.app.ui.screens.contribute

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.os.Build
import app.rollspot.shared.media.PhotoUpload
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream

/**
 * Turns any picked or captured image (JPEG, HEIC, PNG, WebP, huge camera photos) into upload-ready
 * JPEG bytes following the shared [PhotoUpload] rules (iOS: PhotoEncoder.swift): upright, at most
 * [PhotoUpload.maxSide] px, under the backend's size limit. Off the main thread. Null only when the
 * file can't be read at all (e.g. a cloud file that failed to download).
 */
suspend fun jpegForUpload(context: Context, uri: Uri, upload: PhotoUpload = PhotoUpload.Review): ByteArray? =
    withContext(Dispatchers.IO) {
        runCatching {
            val bitmap = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) decode(context, uri, upload) else decodeLegacy(context, uri, upload))
                ?: return@runCatching null
            val opaque = onWhite(bitmap)
            try {
                upload.encodeWithinLimit { quality ->
                    ByteArrayOutputStream().use { out ->
                        if (opaque.compress(Bitmap.CompressFormat.JPEG, quality, out)) out.toByteArray() else null
                    }
                }
            } finally {
                opaque.recycle()
                if (opaque !== bitmap) bitmap.recycle()
            }
        }.getOrNull()
    }

/** Android 9+: decodes HEIC and friends, applies the EXIF rotation and resizes in one pass. */
private fun decode(context: Context, uri: Uri, upload: PhotoUpload): Bitmap? {
    val source = ImageDecoder.createSource(context.contentResolver, uri)
    return ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
        val target = upload.targetSize(info.size.width, info.size.height)
        decoder.setTargetSize(target.width, target.height)
        // Software memory so the bitmap can be compressed and drawn on a canvas.
        decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
    }
}

/** Android 8: sample down while decoding, scale to the exact size, then rotate by hand. */
private fun decodeLegacy(context: Context, uri: Uri, upload: PhotoUpload): Bitmap? {
    val resolver = context.contentResolver
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

    var sample = 1
    while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= upload.maxSide) sample *= 2
    val sampled = resolver.openInputStream(uri)?.use {
        BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
    } ?: return null

    val target = upload.targetSize(sampled.width, sampled.height)
    val degrees = resolver.openInputStream(uri)?.use { stream ->
        when (ExifInterface(stream).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
    } ?: 0f
    val matrix = Matrix().apply {
        postScale(target.width.toFloat() / sampled.width, target.height.toFloat() / sampled.height)
        postRotate(degrees)
    }
    val result = Bitmap.createBitmap(sampled, 0, 0, sampled.width, sampled.height, matrix, true)
    if (result !== sampled) sampled.recycle()
    return result
}

/** JPEG has no transparency: put see-through images (PNG screenshots, stickers) on white, not black. */
private fun onWhite(bitmap: Bitmap): Bitmap {
    if (!bitmap.hasAlpha()) return bitmap
    val flat = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
    Canvas(flat).apply {
        drawColor(Color.WHITE)
        drawBitmap(bitmap, 0f, 0f, null)
    }
    return flat
}
