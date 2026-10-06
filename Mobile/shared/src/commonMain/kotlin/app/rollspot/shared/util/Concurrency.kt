package app.rollspot.shared.util

import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit

/**
 * Runs [work] over [items] with at most [limit] in flight, keeping input order.
 *
 * Firing 25 requests at once on a phone doesn't finish sooner; they all fight
 * for the same connection and starve everything else (map tiles included).
 */
suspend fun <T, R> mapWithLimit(items: List<T>, limit: Int, work: suspend (T) -> R): List<R> = coroutineScope {
    val permits = Semaphore(limit.coerceAtLeast(1))
    items.map { item -> async { permits.withPermit { work(item) } } }.awaitAll()
}
