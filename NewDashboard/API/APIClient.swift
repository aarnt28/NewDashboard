import Foundation
import os

actor APIClient {
    struct Response<ResponseType> {
        let value: ResponseType?
        let etag: String?
        let lastModified: Date?
        let statusCode: Int
        let headers: [AnyHashable: Any]
    }

    private let configuration: AppConfiguration
    private let session: URLSession
    private let telemetry: Telemetry
    weak var authenticationProvider: AuthenticationProviding?

    init(configuration: AppConfiguration,
         session: URLSession,
         telemetry: Telemetry) {
        self.configuration = configuration
        self.session = session
        self.telemetry = telemetry
    }

    func setAuthenticationProvider(_ provider: AuthenticationProviding?) {
        self.authenticationProvider = provider
    }

    func send<Response: Decodable>(_ endpoint: Endpoint<Response>) async throws -> Response<Response> {
        var request = try buildRequest(for: endpoint)
        if let authHeaders = try await authenticationProvider?.authenticationHeaders() {
            for (key, value) in authHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        let logger = telemetry.logger(for: .api)
        logger.debug("→ \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "<unknown>")")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.network(URLError(.badServerResponse))
            }

            let statusCode = httpResponse.statusCode
            switch statusCode {
            case 200..<300:
                do {
                    let value = try endpoint.decoder.decode(Response.self, from: data)
                    return Response(value: value,
                                    etag: httpResponse.value(forHTTPHeaderField: "ETag"),
                                    lastModified: parseLastModified(from: httpResponse),
                                    statusCode: statusCode,
                                    headers: httpResponse.allHeaderFields)
                } catch {
                    throw APIError.decoding(error)
                }
            case 304:
                return Response(value: nil,
                                etag: httpResponse.value(forHTTPHeaderField: "ETag"),
                                lastModified: parseLastModified(from: httpResponse),
                                statusCode: statusCode,
                                headers: httpResponse.allHeaderFields)
            case 401:
                try await authenticationProvider?.handleUnauthorized()
                throw APIError.unauthorized
            case 403:
                throw APIError.forbidden
            case 429:
                let retryAfter = parseRetryAfter(from: httpResponse)
                throw APIError.rateLimited(retryAfter: retryAfter)
            case 500..<600:
                throw APIError.server(status: statusCode)
            default:
                throw APIError.server(status: statusCode)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error)
        }
    }

    private func buildRequest<Response>(for endpoint: Endpoint<Response>) throws -> URLRequest {
        var url = configuration.baseURL
        if endpoint.path.hasPrefix("/") {
            url.append(path: String(endpoint.path.dropFirst()))
        } else {
            url.append(path: endpoint.path)
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
        }

        guard let finalURL = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: finalURL)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = 15
        request.allowsConstrainedNetworkAccess = true

        for (header, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: header)
        }
        if let body = endpoint.body {
            request.httpBody = body.data
            request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }

    private func parseLastModified(from response: HTTPURLResponse) -> Date? {
        guard let value = response.value(forHTTPHeaderField: "Last-Modified") else { return nil }
        return HTTPDateFormatter.shared.date(from: value)
    }

    private func parseRetryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After") else { return nil }
        if let interval = TimeInterval(value) {
            return interval
        }
        if let date = HTTPDateFormatter.shared.date(from: value) {
            return date.timeIntervalSinceNow
        }
        return nil
    }
}

protocol AuthenticationProviding: AnyObject {
    func authenticationHeaders() async throws -> [String: String]
    func handleUnauthorized() async throws
}
