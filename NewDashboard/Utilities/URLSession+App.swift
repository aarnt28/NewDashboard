import Foundation

extension URLSessionConfiguration {
    static func appDefault() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 60
        configuration.allowsCellularAccess = true
        configuration.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Accept-Encoding": "br, gzip, deflate"
        ]
        configuration.httpShouldUsePipelining = true
        configuration.httpShouldSetCookies = true
        return configuration
    }
}
