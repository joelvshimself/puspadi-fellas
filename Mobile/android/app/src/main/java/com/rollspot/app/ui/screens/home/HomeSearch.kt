package com.rollspot.app.ui.screens.home

import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.foundation.interaction.MutableInteractionSource
import com.rollspot.app.ui.theme.glass
import com.rollspot.app.ui.theme.pressScale
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Place
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.res.stringArrayResource
import androidx.compose.ui.res.stringResource
import com.rollspot.app.R
import kotlinx.coroutines.delay
import app.rollspot.shared.map.AreaResult
import app.rollspot.shared.map.MapPin
import app.rollspot.shared.map.MapState
import com.rollspot.app.ui.theme.RollspotBlue

private val SheetShape = RoundedCornerShape(topStart = 34.dp, topEnd = 34.dp)
private val RowShape = RoundedCornerShape(14.dp)
private val PeekHeight = 68.dp

/**
 * The collapsed search: a floating glass capsule like iOS (measured from the iOS app: inset 24dp
 * from each side, 26dp above the bottom, 68dp tall, fully rounded), holding a grabber and a
 * 33dp white capsule field.
 */
@Composable
fun SearchPeek(onClick: () -> Unit, modifier: Modifier = Modifier) {
    val interaction = remember { MutableInteractionSource() }
    Column(
        modifier
            .navigationBarsPadding()
            .padding(start = 24.dp, end = 24.dp, bottom = 26.dp)
            .fillMaxWidth()
            .height(PeekHeight)
            .homeShadow(CircleShape)
            .pressScale(interaction)
            .glass(CircleShape, tint = 0.35f)
            .clickable(interactionSource = interaction, indication = null, onClick = onClick)
            .padding(horizontal = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(Modifier.padding(top = 7.dp, bottom = 6.dp).width(43.dp).height(6.dp).background(Color(0xFF8C8C8C).copy(alpha = 0.7f), CircleShape))
        Row(
            Modifier
                .fillMaxWidth()
                .height(33.dp)
                .background(Color.White.copy(alpha = 0.8f), CircleShape)
                .border(1.dp, Brush.verticalGradient(listOf(Color.Black.copy(alpha = 0.06f), Color.Black.copy(alpha = 0.16f))), CircleShape)
                .padding(horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Default.Search, contentDescription = null, tint = Color(0xFF3C3C43), modifier = Modifier.size(20.dp))
            Text(
                stringResource(R.string.search_a_place),
                Modifier.padding(start = 8.dp),
                fontSize = 17.sp,
                letterSpacing = (-0.43).sp,
                color = Color.Black.copy(alpha = 0.3f),
            )
        }
    }
}

/** The expanded search sheet: nearby places before typing, recents and results after. */
@Composable
fun SearchSheet(
    state: MapState,
    onQueryChange: (String) -> Unit,
    onClose: () -> Unit,
    onPick: (MapPin) -> Unit,
    onPickArea: (AreaResult) -> Unit,
    onSearchNearby: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { focus.requestFocus() }
    // The text lives here, not in the model's flow: a field whose value arrives a frame late
    // makes the keyboard drop or repeat characters. The model still gets every change.
    var field by remember { mutableStateOf(TextFieldValue(state.query, TextRange(state.query.length))) }

    // Expanded sheet: light glass over the dimmed map, below the status bar (as on iOS).
    Box(
        modifier
            .fillMaxSize()
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(start = 8.dp, end = 8.dp, top = 8.dp, bottom = 8.dp)
            .glass(RoundedCornerShape(34.dp), tint = 0.6f),
    ) {
        Column(Modifier.imePadding().padding(horizontal = 16.dp)) {
            Box(Modifier.align(Alignment.CenterHorizontally).padding(top = 8.dp, bottom = 12.dp).width(36.dp).height(5.dp).background(Color(0x40000000), CircleShape))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Row(
                    Modifier.weight(1f).height(48.dp).background(Color.White, CircleShape).border(2.dp, RollspotBlue, CircleShape).padding(horizontal = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Default.Search, contentDescription = null, tint = Color(0xFF3C3C43))
                    Box(Modifier.weight(1f).padding(start = 10.dp)) {
                        if (field.text.isEmpty()) Text(stringResource(R.string.search_a_place), fontSize = 17.sp, letterSpacing = (-0.43).sp, color = Color.Black.copy(alpha = 0.3f))
                        BasicTextField(
                            value = field,
                            onValueChange = {
                                field = it
                                if (it.text != state.query) onQueryChange(it.text)
                            },
                            singleLine = true,
                            textStyle = TextStyle(fontSize = 17.sp, color = Color.Black),
                            cursorBrush = SolidColor(RollspotBlue),
                            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                            modifier = Modifier.fillMaxWidth().focusRequester(focus)
                                .semantics { contentDescription = "Search a place" },
                        )
                    }
                }
                Spacer(Modifier.width(10.dp))
                Box(
                    Modifier.size(48.dp).background(Color.White, CircleShape).clickable(onClick = onClose),
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.Default.Close, contentDescription = stringResource(R.string.close_search), tint = Color(0xFF3C3C43)) }
            }
            Spacer(Modifier.height(16.dp))
            if (state.isSearchActive) SearchResults(state, onSearchNearby, onPick, onPickArea) else NearbyList(state, onPick)
        }
    }
}

@Composable
private fun NearbyList(state: MapState, onPick: (MapPin) -> Unit) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), contentPadding = PaddingValues(bottom = 24.dp)) {
        item { SectionHeader(stringResource(R.string.nearby_malls)) }
        if (state.pins.isEmpty() && state.hasLoaded) {
            item { Message(stringResource(R.string.no_places_nearby)) }
        } else if (state.pins.isEmpty()) {
            item { Box(Modifier.fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() } }
        }
        items(state.pins, key = { it.id }) { pin ->
            ResultRow(Icons.Default.Search, RollspotBlue, pin.place.name, subtitle(pin)) { onPick(pin) }
        }
    }
}

@Composable
private fun SearchResults(state: MapState, onSearchNearby: () -> Unit, onPick: (MapPin) -> Unit, onPickArea: (AreaResult) -> Unit) {
    val query = state.query.trim()
    LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), contentPadding = PaddingValues(bottom = 24.dp)) {
        // Design order: recent places (clock), the "search nearby" action, then results (pin).
        items(state.matchingRecents, key = { "recent-${it.id}" }) { pin ->
            ResultRow(Icons.Default.History, Color(0xFF636366), pin.place.name, subtitle(pin)) { onPick(pin) }
        }
        item { ResultRow(Icons.Default.Search, RollspotBlue, query, stringResource(R.string.search_nearby), onSearchNearby) }
        when {
            state.isSearching -> item { Box(Modifier.fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() } }
            state.error != null -> item { Message(state.error!!) }
            state.freshResults.isEmpty() && state.matchingRecents.isEmpty() && state.areaResults.isEmpty() ->
                item { Message(stringResource(R.string.no_places_found, query)) }
            else -> {
                items(state.freshResults, key = { it.id }) { pin ->
                    ResultRow(Icons.Outlined.Place, RollspotBlue, pin.place.name, subtitle(pin)) { onPick(pin) }
                }
                // Addresses and areas from the phone's geocoder: tapping one moves the map there.
                items(state.areaResults, key = { "area-${it.title}-${it.subtitle}" }) { area ->
                    ResultRow(Icons.Default.LocationOn, Color(0xFF636366), area.title, area.subtitle) { onPickArea(area) }
                }
            }
        }
    }
}

private fun subtitle(pin: MapPin): String =
    listOfNotNull(pin.distanceLabel, pin.place.address?.takeIf { it.isNotBlank() }).joinToString(" • ")

@Composable
private fun SectionHeader(text: String) {
    // iOS SheetMetrics.sectionHeaderSize: 18pt semibold, primary at 80%.
    Text(text, Modifier.padding(top = 4.dp, bottom = 8.dp), color = Color.Black.copy(alpha = 0.8f), fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
}

@Composable
private fun Message(text: String) {
    Text(text, Modifier.fillMaxWidth().padding(24.dp), color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
}

@Composable
private fun ResultRow(icon: androidx.compose.ui.graphics.vector.ImageVector, tint: Color, title: String, subtitle: String, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().background(Color.White, RowShape).clickable(onClick = onClick).padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.width(22.dp), contentAlignment = Alignment.Center) {
            Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(18.dp))
        }
        Spacer(Modifier.width(16.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (subtitle.isNotEmpty()) {
                Text(subtitle, fontSize = 13.sp, color = Color.Black.copy(alpha = 0.7f), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

/** The rotating "Search Malls in around you..." hint from the iOS app: types, holds, deletes, next phrase. */
