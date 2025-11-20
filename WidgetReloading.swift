import Foundation
import WidgetKit

enum WidgetReloader {
    static func reloadOpenTickets() {
        WidgetCenter.shared.reloadTimelines(ofKind: SharedAppConstants.openTicketsWidgetKind)
    }
    static func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
