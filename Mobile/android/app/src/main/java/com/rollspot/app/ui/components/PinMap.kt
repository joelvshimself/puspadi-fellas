package com.rollspot.app.ui.components

import android.annotation.SuppressLint
import android.graphics.PointF
import app.rollspot.shared.map.viewportRadiusMeters
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import app.rollspot.shared.map.MapPin
import app.rollspot.shared.places.OverallAccessibility
import com.rollspot.app.ui.theme.color
import org.maplibre.android.MapLibre
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.location.LocationComponentActivationOptions
import org.maplibre.android.location.modes.RenderMode
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.maplibre.android.style.expressions.Expression
import org.maplibre.android.style.layers.CircleLayer
import org.maplibre.android.style.layers.SymbolLayer
import org.maplibre.android.style.layers.PropertyFactory
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.Feature
import org.maplibre.geojson.FeatureCollection
import org.maplibre.geojson.Point

/** Free, key-less OpenStreetMap vector tiles that allow app use. The public tile.openstreetmap.org servers do not. */
private const val STYLE_URL = "https://tiles.openfreemap.org/styles/liberty"
private const val SOURCE_ID = "pins"
private const val DOT_LAYER_ID = "pins-dots"
private const val ICON_LAYER_ID = "pins-icons"

/** Zoomed out, pins are small dots; from here in they carry their grade glyph (as in the design). */
private const val ICON_MIN_ZOOM = 13.5f
private const val INITIAL_ZOOM = 14.0

/**
 * Ask the map to fly somewhere, to a default zoom or to fit [radiusMeters] around it.
 * [nonce] makes repeated requests for the same spot count.
 */
data class CameraTarget(val lat: Double, val lng: Double, val nonce: Int, val radiusMeters: Int? = null)

/**
 * OpenStreetMap map (MapLibre) drawing [pins] as grade-colored dots. It only
 * reports what happened: the camera stopped ([onCameraIdle] with the visible
 * radius in meters) or a pin was tapped ([onPinClick]). What the pins are is
 * decided by the shared MapModel.
 */
@Composable
fun PinMap(
    pins: List<MapPin>,
    hasLocationPermission: Boolean,
    initialLat: Double,
    initialLng: Double,
    cameraTarget: CameraTarget?,
    onCameraIdle: (lat: Double, lng: Double, radiusMeters: Int) -> Unit,
    onPinClick: (placeId: String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val mapView = remember {
        MapLibre.getInstance(context)
        // TextureView mode: glass surfaces (Haze) can only blur what draws into the view hierarchy.
        MapView(context, org.maplibre.android.maps.MapLibreMapOptions.createFromAttributes(context).textureMode(true))
            .also { it.onCreate(null) }
    }
    var map by remember { mutableStateOf<MapLibreMap?>(null) }
    var styleReady by remember { mutableStateOf(false) }
    val currentOnIdle by rememberUpdatedState(onCameraIdle)
    val currentOnPinClick by rememberUpdatedState(onPinClick)

    DisposableEffect(lifecycle, mapView) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> mapView.onStart()
                Lifecycle.Event.ON_RESUME -> mapView.onResume()
                Lifecycle.Event.ON_PAUSE -> mapView.onPause()
                Lifecycle.Event.ON_STOP -> mapView.onStop()
                else -> Unit
            }
        }
        lifecycle.addObserver(observer)
        // The observer only sees events after it's added; catch up to where the lifecycle already is.
        if (lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) mapView.onStart()
        if (lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) mapView.onResume()
        onDispose {
            lifecycle.removeObserver(observer)
            mapView.onPause()
            mapView.onStop()
            mapView.onDestroy()
        }
    }

    LaunchedEffect(mapView) {
        mapView.getMapAsync { maplibre ->
            map = maplibre
            maplibre.cameraPosition = org.maplibre.android.camera.CameraPosition.Builder()
                .target(LatLng(initialLat, initialLng))
                .zoom(INITIAL_ZOOM)
                .build()
            maplibre.setStyle(Style.Builder().fromUri(STYLE_URL)) { style ->
                val density = context.resources.displayMetrics.density
                OverallAccessibility.entries.forEach { style.addImage(it.pinImageId, pinBitmap(it, density)) }
                style.addSource(GeoJsonSource(SOURCE_ID, FeatureCollection.fromFeatures(emptyList<Feature>())))
                style.addLayer(
                    CircleLayer(DOT_LAYER_ID, SOURCE_ID).withProperties(
                        PropertyFactory.circleColor(Expression.get("color")),
                        PropertyFactory.circleRadius(5.5f),
                        PropertyFactory.circleStrokeColor("#FFFFFF"),
                        PropertyFactory.circleStrokeWidth(1.5f),
                    ).apply { setMaxZoom(ICON_MIN_ZOOM) },
                )
                style.addLayer(
                    SymbolLayer(ICON_LAYER_ID, SOURCE_ID).withProperties(
                        PropertyFactory.iconImage(Expression.get("icon")),
                        PropertyFactory.iconAllowOverlap(true),
                        PropertyFactory.iconIgnorePlacement(true),
                    ).apply { setMinZoom(ICON_MIN_ZOOM) },
                )
                styleReady = true
            }
            maplibre.addOnCameraIdleListener {
                val target = maplibre.cameraPosition.target ?: return@addOnCameraIdleListener
                // Same radius formula as iOS, from the shared module.
                val bounds = maplibre.projection.visibleRegion.latLngBounds
                currentOnIdle(
                    target.latitude,
                    target.longitude,
                    viewportRadiusMeters(target.latitude, bounds.latitudeSpan, bounds.longitudeSpan),
                )
            }
            maplibre.addOnMapClickListener { latLng ->
                val point: PointF = maplibre.projection.toScreenLocation(latLng)
                val hit = maplibre.queryRenderedFeatures(point, DOT_LAYER_ID, ICON_LAYER_ID).firstOrNull()?.getStringProperty("id")
                hit?.let { currentOnPinClick(it) }
                hit != null
            }
        }
    }

    LaunchedEffect(map, styleReady, pins) {
        val style = map?.style?.takeIf { styleReady } ?: return@LaunchedEffect
        val features = pins.map { pin ->
            Feature.fromGeometry(Point.fromLngLat(pin.place.lng, pin.place.lat)).apply {
                addStringProperty("id", pin.id)
                addStringProperty("color", pin.grade.color.toHex())
                addStringProperty("icon", pin.grade.pinImageId)
            }
        }
        style.getSourceAs<GeoJsonSource>(SOURCE_ID)?.setGeoJson(FeatureCollection.fromFeatures(features))
    }

    LaunchedEffect(map, cameraTarget) {
        val target = cameraTarget ?: return@LaunchedEffect
        val radius = target.radiusMeters
        val update = if (radius == null) {
            CameraUpdateFactory.newLatLngZoom(LatLng(target.lat, target.lng), INITIAL_ZOOM)
        } else {
            val dLat = radius / 111_000.0
            val dLng = radius / (111_000.0 * kotlin.math.cos(Math.toRadians(target.lat)).coerceAtLeast(0.2))
            // Regions and countries reach far: keep the box on the map (MapLibre rejects |lat| > 90).
            val bounds = LatLngBounds.Builder()
                .include(LatLng((target.lat - dLat).coerceAtLeast(-85.0), (target.lng - dLng).coerceAtLeast(-180.0)))
                .include(LatLng((target.lat + dLat).coerceAtMost(85.0), (target.lng + dLng).coerceAtMost(180.0)))
                .build()
            CameraUpdateFactory.newLatLngBounds(bounds, 0)
        }
        map?.animateCamera(update)
    }

    // The blue "you are here" dot from the design.
    LaunchedEffect(map, styleReady, hasLocationPermission) {
        val maplibre = map ?: return@LaunchedEffect
        val style = maplibre.style?.takeIf { styleReady && hasLocationPermission } ?: return@LaunchedEffect
        enableLocationDot(maplibre, style, context)
    }

    AndroidView(factory = { mapView }, modifier = modifier)
}

private fun Color.toHex(): String = String.format("#%06X", 0xFFFFFF and toArgb())

@SuppressLint("MissingPermission")
private fun enableLocationDot(map: MapLibreMap, style: Style, context: android.content.Context) {
    val location = map.locationComponent
    location.activateLocationComponent(LocationComponentActivationOptions.builder(context, style).build())
    location.isLocationComponentEnabled = true
    location.renderMode = RenderMode.COMPASS
}
