import Foundation

struct AppConfiguration {
    let baseURL: URL
    let buildChannel: String

    static func load() -> AppConfiguration {
        let bundle = Bundle.main
        guard let baseURLString = bundle.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let baseURL = URL(string: baseURLString) else {
            preconditionFailure("API_BASE_URL must be defined in the active build configuration")
        }

        let buildChannel = (bundle.object(forInfoDictionaryKey: "APP_BUILD_CHANNEL") as? String) ?? "UNKNOWN"
        return AppConfiguration(baseURL: baseURL, buildChannel: buildChannel)
    }
}
