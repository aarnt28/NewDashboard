import Foundation

enum APIError: Error, LocalizedError {
    case unauthorized
    case forbidden
    case rateLimited(retryAfter: TimeInterval?)
    case server(status: Int)
    case decoding(Error)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .forbidden:
            return "You do not have permission to perform this action."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "Too many requests. Try again in \(Int(retryAfter)) seconds."
            } else {
                return "Too many requests. Please try again later."
            }
        case .server(let status):
            return "Server error (\(status)). Please try again later."
        case .decoding:
            return "We ran into an unexpected response from the server."
        case .network(let error):
            return (error as NSError).localizedDescription
        }
    }
}
