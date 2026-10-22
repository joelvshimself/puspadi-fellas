package com.rollspot.app.ui.screens.home

import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.TransformOrigin
import com.rollspot.app.ui.components.ContinueSurveyBanner
import com.rollspot.app.ui.theme.Rollspot
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import com.rollspot.app.ui.theme.LocalHazeState
import com.rollspot.app.ui.theme.glass
import com.rollspot.app.ui.theme.pressScale
import dev.chrisbanes.haze.hazeSource
import android.Manifest
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.NearMe
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PriorityHigh
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.res.stringResource
import com.rollspot.app.R
import kotlinx.coroutines.launch
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.rollspot.shared.map.MapPin
import app.rollspot.shared.places.OverallAccessibility
import app.rollspot.shared.places.PlaceRepository
import com.rollspot.app.data.LocationService
import com.rollspot.app.ui.components.CameraTarget
import com.rollspot.app.ui.components.PinMap
import com.rollspot.app.ui.rollspotSdk
import com.rollspot.app.ui.theme.RollspotBlue
import com.rollspot.app.ui.theme.color

private val PeekHeight = 96.dp

/** The light cyan of the filter button in the design. */
private val FilterButtonTint = Color(0xFFD2F1F9)
private val FilterGrades = listOf(
    OverallAccessibility.ACCESSIBLE,
    OverallAccessibility.PARTIALLY_ACCESSIBLE,
    OverallAccessibility.NOT_ACCESSIBLE,
)

/**
 * Home, per the Figma "Homepage" frames: full-screen OpenStreetMap map with no
 * pins until a grade filter is chosen, filter button top-left, saved/profile
 * pill top-right, location button bottom-right and a search sheet at the bottom.
 * Every rule (which places, search, filter widening) lives in the shared MapModel.
 */
@Composable
fun HomeScreen(navController: NavController, review: String? = null) {
    val sdk = rollspotSdk()
    val viewModel: HomeViewModel = viewModel { HomeViewModel(sdk) }
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val location = remember { LocationService(context) }
    var hasPermission by remember { mutableStateOf(location.hasPermission) }
    var cameraTarget by remember { mutableStateOf<CameraTarget?>(null) }
    var searchOpen by remember { mutableStateOf(false) }
    var filterOpen by remember { mutableStateOf(false) }
    // Saveable: coming back from a place page must not re-center or replay an old focus.
    var centeredOnUser by rememberSaveable { mutableStateOf(false) }
    var handledFocusNonce by rememberSaveable { mutableStateOf(0) }
    val focusManager = androidx.compose.ui.platform.LocalFocusManager.current
    var showIntro by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        if (review == null && !OnboardingIntroPrefs.hasSeen(context)) {
            kotlinx.coroutines.delay(700)
            showIntro = true
        }
    }
    // Home "Continue Survey": the banner shows once per draft, then folds into the profile button.
    val waiting by sdk.drafts.waiting.collectAsStateWithLifecycle()
    var bannerVisible by remember { mutableStateOf(false) }
    var foldedDraftId by rememberSaveable { mutableStateOf<String?>(null) }
    LaunchedEffect(waiting?.placeId) {
        val id = waiting?.placeId
        if (id == null) { bannerVisible = false; return@LaunchedEffect }
        if (id == foldedDraftId) return@LaunchedEffect
        bannerVisible = true
        kotlinx.coroutines.delay(4_000)
        bannerVisible = false
        foldedDraftId = id
    }
    fun resume(placeId: String) {
        bannerVisible = false
        foldedDraftId = placeId
        navController.navigate("contribute/flow/$placeId")
    }

    fun flyTo(lat: Double, lng: Double, radiusMeters: Int? = null) {
        cameraTarget = CameraTarget(lat, lng, (cameraTarget?.nonce ?: 0) + 1, radiusMeters)
    }

    val scope = rememberCoroutineScope()
    fun centerOnMe() {
        scope.launch { location.currentLocation()?.let { flyTo(it.latitude, it.longitude) } }
    }

    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        hasPermission = location.hasPermission
        centerOnMe()
    }
    fun requestPermission() =
        permissionLauncher.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))

    LaunchedEffect(Unit) {
        if (review != null) return@LaunchedEffect // design review pins the camera itself
        if (location.hasPermission) {
            if (!centeredOnUser) { centeredOnUser = true; centerOnMe() }
        } else {
            requestPermission()
        }
    }
    // The filter widened the search area: move the camera to what it found.
    LaunchedEffect(state.focus) {
        val focus = state.focus ?: return@LaunchedEffect
        if (focus.nonce == handledFocusNonce) return@LaunchedEffect
        handledFocusNonce = focus.nonce
        flyTo(focus.lat, focus.lng, focus.radiusMeters)
    }

    fun open(pin: MapPin) {
        viewModel.select(pin)
        searchOpen = false
        viewModel.clearQuery()
        navController.navigate("place/${pin.id}")
    }

    // Debug design review (same states as iOS -designReview home*).
    LaunchedEffect(review) {
        if (review == null) return@LaunchedEffect
        flyTo(-8.7180, 115.1700) // same area as the iOS review shots (Kuta)
        kotlinx.coroutines.delay(3_000) // let nearby places load first
        when (review) {
            "homeFilter" -> filterOpen = true
            "homeFilterChosen" -> viewModel.setGradeFilter(OverallAccessibility.ACCESSIBLE)
            "homeSearch" -> searchOpen = true
            "homeSearchQuery" -> { viewModel.onQueryChanged("beach"); searchOpen = true }
        }
    }

    BackHandler(enabled = searchOpen || filterOpen) {
        if (searchOpen) { searchOpen = false; viewModel.clearQuery() } else filterOpen = false
    }

    val haze = remember { dev.chrisbanes.haze.HazeState() }
    CompositionLocalProvider(LocalHazeState provides haze) {
    Box(Modifier.fillMaxSize()) {
        PinMap(
            pins = state.visiblePins,
            hasLocationPermission = hasPermission,
            initialLat = state.centerLat,
            initialLng = state.centerLng,
            cameraTarget = cameraTarget,
            onCameraIdle = viewModel::onRegionChanged,
            onPinClick = { id -> state.pins.firstOrNull { it.id == id }?.let(::open) },
            modifier = Modifier.fillMaxSize().hazeSource(haze),
        )

        if (state.isLoading || state.isWidening) {
            LinearProgressIndicator(Modifier.fillMaxWidth().statusBarsPadding())
        }

        // Top bar
        Row(
            Modifier.fillMaxWidth().statusBarsPadding().padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box {
                CircleButton(Icons.Default.FilterList, stringResource(R.string.filter_accessibility), tint = FilterButtonTint.copy(alpha = 0.45f)) { filterOpen = !filterOpen }
                if (state.gradeFilter != null) {
                    Box(
                        Modifier.align(Alignment.TopEnd).offset(x = 4.dp, y = (-4).dp).size(18.dp)
                            .background(RollspotBlue, CircleShape).border(2.dp, Color.White, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) { Text("1", color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold) }
                }
            }
            // Saved + profile share one glass capsule (iOS homeGlass on the same pill).
            Row(
                Modifier.homeShadow(CircleShape).height(48.dp).glass(CircleShape).padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(22.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Default.Bookmark, stringResource(R.string.saved_places), Modifier.size(22.dp).clickable { navController.navigate("saved") })
                Box {
                    Icon(Icons.Default.Person, stringResource(R.string.profile), Modifier.size(22.dp).clickable { navController.navigate("profile") })
                    // The folded banner: one contribution waiting.
                    androidx.compose.animation.AnimatedVisibility(
                        waiting != null && !bannerVisible,
                        Modifier.align(Alignment.TopEnd).offset(x = 10.dp, y = (-10).dp),
                        enter = scaleIn(initialScale = 0.6f) + fadeIn(),
                        exit = scaleOut(targetScale = 0.6f) + fadeOut(),
                    ) {
                        Box(
                            Modifier.size(18.dp).background(RollspotBlue, CircleShape).border(2.dp, Color.White, CircleShape),
                            contentAlignment = Alignment.Center,
                        ) { Text("1", color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold) }
                    }
                }
            }
        }

        // "Continue Survey" banner under the top bar; it folds up into the profile button.
        val reduceMotion = remember { !android.animation.ValueAnimator.areAnimatorsEnabled() }
        androidx.compose.animation.AnimatedVisibility(
            visible = bannerVisible && waiting != null && !searchOpen && !filterOpen,
            modifier = Modifier.align(Alignment.TopCenter).statusBarsPadding().padding(start = 16.dp, end = 16.dp, top = 72.dp),
            enter = slideInVertically(tween(250, easing = Rollspot.EaseOut)) { -it / 2 } + fadeIn(tween(250)),
            exit = if (reduceMotion) fadeOut(tween(200)) else scaleOut(
                spring(dampingRatio = 0.85f, stiffness = 300f), targetScale = 0.15f, transformOrigin = TransformOrigin(1f, 0f),
            ) + fadeOut(tween(300)),
        ) {
            val shape = RoundedCornerShape(20.dp)
            waiting?.let { contribution ->
                ContinueSurveyBanner(
                    contribution,
                    onOpen = { resume(contribution.placeId) },
                    modifier = Modifier.fillMaxWidth().shadow(12.dp, shape, ambientColor = Color(0x1F000000), spotColor = Color(0x1F000000)).glass(shape, tint = 0.7f),
                )
            }
        }

        // Location button and attribution, floated above the peek sheet
        Row(
            Modifier.align(Alignment.BottomCenter).fillMaxWidth().navigationBarsPadding()
                .padding(start = 16.dp, end = 16.dp, bottom = PeekHeight + 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Bottom,
        ) {
            Surface(shape = MaterialTheme.shapes.extraSmall, color = Color.White.copy(alpha = 0.85f)) {
                Text(PlaceRepository.ATTRIBUTION, Modifier.padding(horizontal = 6.dp, vertical = 2.dp), style = MaterialTheme.typography.labelSmall)
            }
            CircleButton(Icons.Default.NearMe, stringResource(R.string.my_location)) {
                if (hasPermission) centerOnMe() else requestPermission()
            }
        }

        SearchPeek(onClick = { searchOpen = true }, modifier = Modifier.align(Alignment.BottomCenter))

        state.error?.let {
            // Under the top bar so it never covers the location button; tap to try again.
            Surface(
                Modifier.align(Alignment.TopCenter).statusBarsPadding().padding(top = 72.dp, start = 16.dp, end = 16.dp).clickable { viewModel.retry() },
                shape = MaterialTheme.shapes.small,
                color = MaterialTheme.colorScheme.errorContainer,
            ) {
                Text(stringResource(R.string.tap_to_retry, it), Modifier.padding(12.dp), color = MaterialTheme.colorScheme.onErrorContainer)
            }
        }

        if (filterOpen) {
            FilterPanel(
                selected = state.gradeFilter,
                onSelect = { viewModel.setGradeFilter(it); filterOpen = false },
                onDismiss = { filterOpen = false },
            )
        }

        if (searchOpen) {
            // iOS search scrim: rgba(181,181,181,0.6) over a blurred map.
            Box(Modifier.fillMaxSize().glass(androidx.compose.ui.graphics.RectangleShape, tint = 0f, blur = 12.dp).background(Color(0x99B5B5B5)))
            SearchSheet(
                state = state,
                onQueryChange = viewModel::onQueryChanged,
                onClose = { searchOpen = false; viewModel.clearQuery() },
                onPick = ::open,
                onSearchNearby = { focusManager.clearFocus() },
            )
        }

        // One-time intro over the map (iOS OnboardingIntroSheet), shortly after the first launch.
        OnboardingIntroSheet(visible = showIntro, onExplore = {
            OnboardingIntroPrefs.markSeen(context)
            showIntro = false
        })
    }
    }
}

@Composable
private fun CircleButton(
    icon: ImageVector,
    description: String,
    tint: Color = Color.Transparent,
    onClick: () -> Unit,
) {
    // 48dp Liquid-Glass-style circle with iOS's button shadow (ButtonsTop 285:1346).
    val interaction = remember { MutableInteractionSource() }
    Box(
        Modifier
            .homeShadow(CircleShape)
            .size(48.dp)
            .pressScale(interaction)
            .glass(CircleShape)
            .background(tint, CircleShape)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) { Icon(icon, contentDescription = null, Modifier.size(22.dp), tint = Color(0xFF1C1C1E)) }
}

/** iOS SheetMetrics button shadow: 25% black, radius ~3, y 3.7. */
internal fun Modifier.homeShadow(shape: androidx.compose.ui.graphics.Shape): Modifier =
    this.shadow(elevation = 4.dp, shape = shape, ambientColor = Color.Black.copy(alpha = 0.25f), spotColor = Color.Black.copy(alpha = 0.25f))

/** The filter fan-out from the design: dimmed map, one round option per grade. */
@Composable
private fun FilterPanel(selected: OverallAccessibility?, onSelect: (OverallAccessibility) -> Unit, onDismiss: () -> Unit) {
    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.45f)).clickable(onClick = onDismiss))
    Column(
        Modifier.statusBarsPadding().padding(start = 16.dp + 48.dp + 12.dp, top = 12.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        FilterGrades.forEach { grade ->
            val isOn = selected == grade
            Row(Modifier.clickable { onSelect(grade) }, verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier.size(48.dp).background(grade.color, CircleShape)
                        .then(if (isOn) Modifier.border(3.dp, Color.White, CircleShape) else Modifier),
                    contentAlignment = Alignment.Center,
                ) { Icon(grade.filterIcon, contentDescription = null, tint = Color.White, modifier = Modifier.size(28.dp)) }
                Text(
                    grade.filterLabel(),
                    Modifier.padding(start = 14.dp),
                    color = Color.White,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
}

private val OverallAccessibility.filterIcon: ImageVector
    get() = when (this) {
        OverallAccessibility.ACCESSIBLE -> Icons.Default.Check
        OverallAccessibility.PARTIALLY_ACCESSIBLE -> Icons.Default.PriorityHigh
        else -> Icons.Default.Close
    }

/** The design says "Partially Accessible" here; the badge elsewhere says "Moderately". */
@Composable
private fun OverallAccessibility.filterLabel(): String = stringResource(
    when (this) {
        OverallAccessibility.ACCESSIBLE -> R.string.accessible
        OverallAccessibility.PARTIALLY_ACCESSIBLE -> R.string.partially_accessible
        else -> R.string.not_accessible
    },
)
