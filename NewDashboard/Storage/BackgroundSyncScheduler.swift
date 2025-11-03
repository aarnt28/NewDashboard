import Foundation
import BackgroundTasks
import os

final class BackgroundSyncScheduler {
    private let telemetry: Telemetry
    private let logger: Logger

    init(telemetry: Telemetry) {
        self.telemetry = telemetry
        self.logger = telemetry.logger(for: .sync)
    }

    func register(handler: @escaping () async -> Void) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.example.NewDashboard.sync", using: nil) { task in
            self.logger.debug("Running background sync task")
            Task {
                await handler()
                task.setTaskCompleted(success: true)
                await self.schedule()
            }
        }
    }

    @discardableResult
    func schedule() async -> Bool {
        let request = BGAppRefreshTaskRequest(identifier: "com.example.NewDashboard.sync")
        request.earliestBeginDate = Date().addingTimeInterval(60 * 15)
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.debug("Scheduled background sync task")
            return true
        } catch {
            logger.error("Failed to schedule background sync: \(error.localizedDescription)")
            return false
        }
    }
}
