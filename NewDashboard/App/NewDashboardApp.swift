import SwiftUI
import SwiftData

@main
struct NewDashboardApp: App {
    @StateObject private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootShellView()
                .environmentObject(environment)
                .modelContainer(environment.modelContainer)
                .task {
                    await environment.bootstrap()
                }
        }
    }
}
