import Foundation

enum APIClientError: LocalizedError {
    case invalidResponse
    case http(status: Int, message: String)
    case missingSessionToken

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The server returned an invalid response."
        case .http(_, let message):
            message
        case .missingSessionToken:
            "The login completed without a session. Please try again."
        }
    }
}

private struct APIErrorBody: Decodable {
    let message: String?
    let error: String?
}

/// The app's one network boundary. It owns authentication headers and JSON
/// conventions so feature services remain small and testable.
final class CloudflareAPIClient: @unchecked Sendable {
    static let shared = CloudflareAPIClient()

    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func get<Response: Decodable>(_ components: [String], authenticated: Bool = false) async throws -> Response {
        try await request(components, method: "GET", authenticated: authenticated)
    }

    func get<Response: Decodable>(
        _ components: [String],
        authenticated: Bool = false,
        decoder customDecoder: JSONDecoder
    ) async throws -> Response {
        let (data, _) = try await dataResponse(
            components,
            method: "GET",
            body: nil,
            contentType: nil,
            authenticated: authenticated,
            capturesSession: false
        )
        return try customDecoder.decode(Response.self, from: data)
    }

    func post<Body: Encodable, Response: Decodable>(
        _ components: [String],
        body: Body,
        authenticated: Bool = false,
        capturesSession: Bool = false
    ) async throws -> Response {
        try await request(
            components,
            method: "POST",
            body: encoder.encode(body),
            contentType: "application/json",
            authenticated: authenticated,
            capturesSession: capturesSession
        )
    }

    func patch<Body: Encodable, Response: Decodable>(
        _ components: [String],
        body: Body,
        authenticated: Bool = true
    ) async throws -> Response {
        try await request(
            components,
            method: "PATCH",
            body: encoder.encode(body),
            contentType: "application/json",
            authenticated: authenticated
        )
    }

    func put<Body: Encodable>(_ components: [String], body: Body, authenticated: Bool = true) async throws {
        try await send(
            components,
            method: "PUT",
            body: encoder.encode(body),
            contentType: "application/json",
            authenticated: authenticated
        )
    }

    func putData<Response: Decodable>(
        _ components: [String],
        data: Data,
        contentType: String,
        authenticated: Bool = true
    ) async throws -> Response {
        try await request(
            components,
            method: "PUT",
            body: data,
            contentType: contentType,
            authenticated: authenticated
        )
    }

    func delete(_ components: [String], authenticated: Bool = true) async throws {
        try await send(components, method: "DELETE", authenticated: authenticated)
    }

    func send(
        _ components: [String],
        method: String,
        body: Data? = nil,
        contentType: String? = nil,
        authenticated: Bool = false
    ) async throws {
        _ = try await dataResponse(
            components,
            method: method,
            body: body,
            contentType: contentType,
            authenticated: authenticated,
            capturesSession: false
        )
    }

    private func request<Response: Decodable>(
        _ components: [String],
        method: String,
        body: Data? = nil,
        contentType: String? = nil,
        authenticated: Bool,
        capturesSession: Bool = false
    ) async throws -> Response {
        let (data, _) = try await dataResponse(
            components,
            method: method,
            body: body,
            contentType: contentType,
            authenticated: authenticated,
            capturesSession: capturesSession
        )
        return try decoder.decode(Response.self, from: data)
    }

    private func dataResponse(
        _ components: [String],
        method: String,
        body: Data?,
        contentType: String?,
        authenticated: Bool,
        capturesSession: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: Self.url(components))
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 30
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        if authenticated {
            guard let token = AuthTokenStore.load() else { throw APIClientError.missingSessionToken }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let body = try? decoder.decode(APIErrorBody.self, from: data)
            throw APIClientError.http(
                status: http.statusCode,
                message: body?.message ?? body?.error ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            )
        }
        if capturesSession {
            guard let token = http.value(forHTTPHeaderField: "set-auth-token"), !token.isEmpty else {
                throw APIClientError.missingSessionToken
            }
            try AuthTokenStore.save(token)
        }
        return (data, http)
    }

    private static func url(_ components: [String]) -> URL {
        components.reduce(CloudflareConfig.apiBaseURL) { partial, component in
            partial.appendingPathComponent(component)
        }
    }
}

extension Notification.Name {
    static let rollspotAuthStateDidChange = Notification.Name("rollspotAuthStateDidChange")
}
