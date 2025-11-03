import Foundation
import os

struct Telemetry {
    enum Category: String {
        case api
        case sync
        case ui
    }

    func logger(for category: Category) -> Logger {
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.example.NewDashboard", category: category.rawValue)
    }
}
