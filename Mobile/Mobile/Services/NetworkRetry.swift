import Foundation

/// Retries transient network failures (timeouts, dropped connections).
enum NetworkRetry {
    private static let retryableCodes: Set<URLError.Code> = [
        .timedOut,
        .networkConnectionLost,
    ]

    static func run<T>(
        maxAttempts: Int = 3,
        initialDelay: Duration = .milliseconds(400),
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                guard isRetryable(error), attempt < maxAttempts - 1 else { throw error }
                let delay = initialDelay * (1 << attempt)
                try await Task.sleep(for: delay)
            }
        }
        throw lastError ?? URLError(.unknown)
    }

    static func download(from url: URL) async throws -> Data {
        try await run {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            return data
        }
    }

    private static func isRetryable(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        return retryableCodes.contains(urlError.code)
    }
}
