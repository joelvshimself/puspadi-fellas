import Foundation

/// Runs `work` across `items` with at most `limit` running at once.
///
/// Unbounded task groups are the wrong tool for network fan-out on a phone:
/// firing 25 requests at once does not make them finish sooner, it just makes
/// them all contend for the same connection and starves whatever else the app
/// is doing — map tiles included. A small window keeps throughput while
/// leaving the device responsive.
func mapWithLimit<Item, Result>(
    _ items: [Item],
    limit: Int,
    _ work: @escaping (Item) async -> Result
) async -> [Result] {
    guard !items.isEmpty else { return [] }
    let window = max(1, limit)

    return await withTaskGroup(of: Result.self) { group in
        var results: [Result] = []
        results.reserveCapacity(items.count)

        var next = 0
        while next < min(window, items.count) {
            let item = items[next]
            group.addTask { await work(item) }
            next += 1
        }

        while let finished = await group.next() {
            results.append(finished)
            if next < items.count {
                let item = items[next]
                group.addTask { await work(item) }
                next += 1
            }
        }
        return results
    }
}
