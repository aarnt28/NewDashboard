import Foundation

/// Shared constants used by the main app and the widget.
/// IMPORTANT: Add an App Group with this identifier to both the app target and the widget extension target in Xcode.
/// Example: In Signing & Capabilities, add a new App Group: group.vipdashboard.shared
enum SharedAppConstants {
    /// App Group suite identifier used to share settings (baseURL, apiKey) with the widget.
    static let appGroupSuite = "group.vipdashboard.shared"

    /// The WidgetKit kind string for the Open Tickets widget.
    static let openTicketsWidgetKind = "OpenTicketsWidget"
}
