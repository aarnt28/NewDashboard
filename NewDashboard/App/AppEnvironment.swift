import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
final class AppEnvironment: ObservableObject {
    @Published private(set) var authenticationState: AuthenticationController.State = .loading
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var syncError: String?

    let configuration: AppConfiguration
    let telemetry: Telemetry
    let keychainStore: KeychainStore
    let urlSession: URLSession
    let modelContainer: ModelContainer
    let apiClient: APIClient
    let authenticationController: AuthenticationController
    let syncEngine: SyncEngine
    let backgroundScheduler: BackgroundSyncScheduler

    private var cancellables: Set<AnyCancellable> = []

    init() {
        self.configuration = AppConfiguration.load()
        self.telemetry = Telemetry()
        self.keychainStore = KeychainStore()
        self.urlSession = URLSession(configuration: .appDefault())

        let schema = Schema([
            ClientEntity.self,
            TicketEntity.self,
            TicketAttachmentEntity.self,
            HardwareEntity.self,
            InventoryEventEntity.self,
            SyncMetadataEntity.self,
            PendingInventoryAdjustmentEntity.self
        ])
        self.modelContainer = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: false))
        let context = modelContainer.mainContext

        self.apiClient = APIClient(configuration: configuration, session: urlSession, telemetry: telemetry)
        self.authenticationController = AuthenticationController(configuration: configuration,
                                                                   keychain: keychainStore,
                                                                   session: urlSession,
                                                                   telemetry: telemetry)
        self.syncEngine = SyncEngine(apiClient: apiClient, context: context, telemetry: telemetry)
        self.backgroundScheduler = BackgroundSyncScheduler(telemetry: telemetry)

        Task { await apiClient.setAuthenticationProvider(authenticationController) }

        authenticationController.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.authenticationState = state
            }
            .store(in: &cancellables)

        syncEngine.$isSyncing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.isSyncing = value }
            .store(in: &cancellables)
        syncEngine.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in self?.syncError = error }
            .store(in: &cancellables)
    }

    func bootstrap() async {
        await authenticationController.bootstrap()
        backgroundScheduler.register { [weak self] in
            await self?.syncEngine.syncAll()
        }
        _ = await backgroundScheduler.schedule()
        if case .authenticated = authenticationController.state {
            await syncEngine.syncAll()
        }
    }

    func refreshAll() {
        Task { await syncEngine.syncAll() }
    }
}
