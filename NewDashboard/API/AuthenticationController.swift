import Foundation
import os

@MainActor
final class AuthenticationController: ObservableObject, AuthenticationProviding {
    enum State: Equatable {
        case loading
        case needsAPIKey
        case authenticated(userFacingToken: String)
    }

    @Published private(set) var state: State = .loading

    private struct TokenSession: Codable {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Date
    }

    private let configuration: AppConfiguration
    private let keychain: KeychainStore
    private let session: URLSession
    private let telemetry: Telemetry
    private let logger: Logger

    private var cachedSession: TokenSession?

    init(configuration: AppConfiguration,
         keychain: KeychainStore,
         session: URLSession,
         telemetry: Telemetry) {
        self.configuration = configuration
        self.keychain = keychain
        self.session = session
        self.telemetry = telemetry
        self.logger = telemetry.logger(for: .api)
    }

    func bootstrap() async {
        if let access = await keychain.value(for: .accessToken),
           let refresh = await keychain.value(for: .refreshToken),
           let expiryRaw = await keychain.value(for: .tokenExpiry),
           let expiry = ISO8601DateFormatter().date(from: expiryRaw) {
            cachedSession = TokenSession(accessToken: access, refreshToken: refresh, expiresAt: expiry)
            state = .authenticated(userFacingToken: access.masked())
        } else if let apiKey = await keychain.value(for: .apiKey), !apiKey.isEmpty {
            state = .authenticated(userFacingToken: apiKey.masked())
        } else {
            state = .needsAPIKey
        }
    }

    func authenticationHeaders() async throws -> [String: String] {
        if let session = cachedSession, session.expiresAt > Date() {
            return ["Authorization": "Bearer \(session.accessToken)"]
        }

        if let refreshed = try await refreshIfNeeded() {
            return ["Authorization": "Bearer \(refreshed.accessToken)"]
        }

        if let apiKey = await keychain.value(for: .apiKey), !apiKey.isEmpty {
            return ["X-API-Key": apiKey]
        }

        throw APIError.unauthorized
    }

    func updateAPIKey(_ key: String) async {
        await keychain.set(key, for: .apiKey)
        cachedSession = nil
        state = .authenticated(userFacingToken: key.masked())
    }

    func clearCredentials() async {
        await keychain.removeAll()
        cachedSession = nil
        state = .needsAPIKey
    }

    func handleUnauthorized() async throws {
        cachedSession = nil
        await keychain.set(nil, for: .accessToken)
        await keychain.set(nil, for: .refreshToken)
        await keychain.set(nil, for: .tokenExpiry)
        // Preserve API key so the user does not need to re-enter it.
        state = .needsAPIKey
    }

    private func refreshIfNeeded() async throws -> TokenSession? {
        guard let refreshToken = await keychain.value(for: .refreshToken) else { return nil }
        struct RefreshPayload: Encodable { let refreshToken: String }
        var request = URLRequest(url: configuration.baseURL.appending(path: "auth/token"))
        request.httpMethod = HTTPMethod.post.rawValue
        request.httpBody = try? Endpoint.jsonBody(RefreshPayload(refreshToken: refreshToken)).data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard 200..<300 ~= httpResponse.statusCode else {
                logger.error("Failed to refresh token: status \(httpResponse.statusCode)")
                await clearCredentials()
                throw APIError.unauthorized
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
            let expiresAt = tokenResponse.accessTokenExpiry
            let session = TokenSession(accessToken: tokenResponse.accessToken,
                                       refreshToken: tokenResponse.refreshToken,
                                       expiresAt: expiresAt)
            cachedSession = session
            await persist(session: session)
            state = .authenticated(userFacingToken: session.accessToken.masked())
            return session
        } catch {
            throw APIError.network(error)
        }
    }

    func exchangeAPIKeyForJWT() async throws {
        guard let apiKey = await keychain.value(for: .apiKey), !apiKey.isEmpty else { return }
        struct ExchangePayload: Encodable { let apiKey: String }
        var request = URLRequest(url: configuration.baseURL.appending(path: "auth/token"))
        request.httpMethod = HTTPMethod.post.rawValue
        request.httpBody = try? Endpoint.jsonBody(ExchangePayload(apiKey: apiKey)).data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.network(URLError(.badServerResponse))
            }
            guard 200..<300 ~= httpResponse.statusCode else {
                logger.error("Token exchange failed with status \(httpResponse.statusCode)")
                return
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
            let expiresAt = tokenResponse.accessTokenExpiry
            let session = TokenSession(accessToken: tokenResponse.accessToken,
                                       refreshToken: tokenResponse.refreshToken,
                                       expiresAt: expiresAt)
            cachedSession = session
            await persist(session: session)
            state = .authenticated(userFacingToken: session.accessToken.masked())
        } catch {
            logger.error("Token exchange failed: \(error.localizedDescription)")
        }
    }

    private func persist(session: TokenSession) async {
        await keychain.set(session.accessToken, for: .accessToken)
        await keychain.set(session.refreshToken, for: .refreshToken)
        let formatter = ISO8601DateFormatter()
        await keychain.set(formatter.string(from: session.expiresAt), for: .tokenExpiry)
    }

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: TimeInterval

        var accessTokenExpiry: Date {
            Date().addingTimeInterval(expiresIn)
        }

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
        }
    }
}

private extension String {
    func masked() -> String {
        guard count > 8 else { return String(repeating: "•", count: max(3, count)) }
        let prefix = prefix(4)
        let suffix = suffix(4)
        return "\(prefix)…\(suffix)"
    }
}
