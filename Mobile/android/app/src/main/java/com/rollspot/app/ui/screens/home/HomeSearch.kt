package com.rollspot.app.ui.screens.home

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
import app.rollspot.shared.map.MapPin
import app.rollspot.shared.map.MapState
import com.rollspot.app.ui.theme.RollspotBlue

private val SheetShape = RoundedCornerShape(topStart = 34.dp, topEnd = 34.dp)
private val RowShape = RoundedCornerShape(14.dp)
private val PeekHeight = 96.dp

/** The collapsed bottom sheet: a grabber and the search field ("Search a place"). */
@Composable
fun SearchPeek(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Surface(
        modifier = modifier.fillMaxWidth().clickable(onClick = onClick),
        shape = SheetShape,
        color = Color.Transparent,
        shadowElevation = 12.dp,
    ) {
        Column(
            // Frosted white fading into the soft blue glow at the bottom edge, as in the design.
            Modifier
                .background(Brush.verticalGradient(listOf(Color(0xEBFFFFFF), Color(0xEBF4F8FF), Color(0xF2CFE0F8))))
                .navigationBarsPadding()
                .padding(horizontal = 16.dp)
                .height(PeekHeight),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(Modifier.padding(top = 8.dp, bottom = 12.dp).width(36.dp).height(5.dp).background(Color(0x40000000), CircleShape))
            Row(
                Modifier.fillMaxWidth().height(48.dp).background(Color.White, CircleShape).padding(horizontal = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Default.Search, contentDescription = null, tint = Color(0xFF3C3C43))
                Text("Search a place", Modifier.padding(start = 10.dp), color = Color(0xFF8A8A8E), fontSize = 17.sp)
            }
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
    onSearchNearby: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { focus.requestFocus() }
    // The text lives here, not in the model's flow: a field whose value arrives a frame late
    // makes the keyboard drop or repeat characters. The model still gets every change.
    var field by remember { mutableStateOf(TextFieldValue(state.query, TextRange(state.query.length))) }

    Surface(
        modifier = modifier.fillMaxSize(),
        shape = SheetShape,
        color = Color(0xFFF2F2F7),
    ) {
        Column(Modifier.statusBarsPadding().imePadding().padding(horizontal = 16.dp)) {
            Box(Modifier.align(Alignment.CenterHorizontally).padding(top = 8.dp, bottom = 12.dp).width(36.dp).height(5.dp).background(Color(0x40000000), CircleShape))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Row(
                    Modifier.weight(1f).height(48.dp).background(Color.White, CircleShape).border(2.dp, RollspotBlue, CircleShape).padding(horizontal = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Default.Search, contentDescription = null, tint = Color(0xFF3C3C43))
                    Box(Modifier.weight(1f).padding(start = 10.dp)) {
                        if (field.text.isEmpty()) Text("Search a place", color = Color(0xFFB0B0B5), fontSize = 17.sp)
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
                            modifier = Modifier.fillMaxWidth().focusRequester(focus),
                        )
                    }
                }
                Spacer(Modifier.width(10.dp))
                Box(
                    Modifier.size(48.dp).background(Color.White, CircleShape).clickable(onClick = onClose),
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.Default.Close, contentDescription = "Close search", tint = Color(0xFF3C3C43)) }
            }
            Spacer(Modifier.height(16.dp))
            if (state.isSearchActive) SearchResults(state, onSearchNearby, onPick) else NearbyList(state, onPick)
        }
    }
}

@Composable
private fun NearbyList(state: MapState, onPick: (MapPin) -> Unit) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), contentPadding = PaddingValues(bottom = 24.dp)) {
        item { SectionHeader("Nearby Malls") }
        if (state.pins.isEmpty()) {
            item { Box(Modifier.fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() } }
        }
        items(state.pins, key = { it.id }) { pin ->
            ResultRow(Icons.Default.Search, RollspotBlue, pin.place.name, subtitle(pin)) { onPick(pin) }
        }
    }
}

@Composable
private fun SearchResults(state: MapState, onSearchNearby: () -> Unit, onPick: (MapPin) -> Unit) {
    val query = state.query.trim()
    LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), contentPadding = PaddingValues(bottom = 24.dp)) {
        // Design order: recent places (clock), the "search nearby" action, then results (pin).
        items(state.matchingRecents, key = { "recent-${it.id}" }) { pin ->
            ResultRow(Icons.Default.History, Color(0xFF636366), pin.place.name, subtitle(pin)) { onPick(pin) }
        }
        item { ResultRow(Icons.Default.Search, RollspotBlue, query, "Search nearby", onSearchNearby) }
        when {
            state.isSearching -> item { Box(Modifier.fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() } }
            state.error != null -> item { Message(state.error!!) }
            state.freshResults.isEmpty() && state.matchingRecents.isEmpty() -> item { Message("No places found for \"$query\" near here.") }
            else -> items(state.freshResults, key = { it.id }) { pin ->
                ResultRow(Icons.Default.LocationOn, RollspotBlue, pin.place.name, subtitle(pin)) { onPick(pin) }
            }
        }
    }
}

private fun subtitle(pin: MapPin): String =
    listOfNotNull(pin.distanceLabel, pin.place.address?.takeIf { it.isNotBlank() }).joinToString(" • ")

@Composable
private fun SectionHeader(text: String) {
    Text(text, Modifier.padding(start = 6.dp, top = 4.dp, bottom = 4.dp), color = Color(0xFF636366), fontSize = 17.sp)
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
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(16.dp))
        Column(Modifier.weight(1f)) {
            Text(title, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (subtitle.isNotEmpty()) {
                Text(subtitle, fontSize = 13.sp, color = Color(0xFF636366), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}
