import Foundation

struct Endpoint<Response: Decodable> {
    struct Body {
        let data: Data
        let contentType: String
    }

    let path: String
    let method: HTTPMethod
    var queryItems: [URLQueryItem]
    var headers: [String: String]
    var body: Body?
    var decoder: JSONDecoder

    init(path: String,
         method: HTTPMethod = .get,
         queryItems: [URLQueryItem] = [],
         headers: [String: String] = [:],
         body: Body? = nil,
         decoder: JSONDecoder = Endpoint.defaultDecoder) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.decoder = decoder
    }
}

extension Endpoint {
    static var defaultDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func jsonBody<T: Encodable>(_ value: T) throws -> Body {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return Body(data: data, contentType: "application/json")
    }
}
