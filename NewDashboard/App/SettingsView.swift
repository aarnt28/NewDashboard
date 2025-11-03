import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var isClearingCache = false
    @State private var exportText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Connection")) {
                    HStack {
                        Label("Base URL", systemImage: "link")
                        Spacer()
                        Text(environment.configuration.baseURL.absoluteString)
                            .multilineTextAlignment(.trailing)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Channel", systemImage: "tag")
                        Spacer()
                        Text(environment.configuration.buildChannel)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Token", systemImage: "key")
                        Spacer()
                        Text(tokenStatusText)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("Sync")) {
                    ForEach(SyncEngine.Entity.allCases, id: \.self) { entity in
                        HStack {
                            Text(entityTitle(entity))
                            Spacer()
                            if let date = environment.syncEngine.lastSyncDates[entity] {
                                Text(date, style: .relative)
                            } else {
                                Text("Not synced")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let error = environment.syncEngine.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Button("Refresh Now") {
                        environment.refreshAll()
                    }
                    .disabled(environment.isSyncing)
                }

                Section(header: Text("Data")) {
                    Button(role: .destructive) {
                        Task { await clearCache() }
                    } label: {
                        if isClearingCache {
                            ProgressView()
                        } else {
                            Text("Clear Local Cache")
                        }
                    }

                    ShareLink(item: exportText.isEmpty ? generateDiagnostics() : exportText) {
                        Label("Export Logs", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                exportText = generateDiagnostics()
            }
        }
    }

    private var tokenStatusText: String {
        switch environment.authenticationState {
        case .loading:
            return "Loading…"
        case .needsAPIKey:
            return "API key required"
        case .authenticated(let token):
            return token
        }
    }

    private func entityTitle(_ entity: SyncEngine.Entity) -> String {
        switch entity {
        case .tickets: return "Tickets"
        case .clients: return "Clients"
        case .hardware: return "Hardware"
        case .inventoryEvents: return "Inventory"
        }
    }

    private func clearCache() async {
        isClearingCache = true
        do {
            try context.delete(model: TicketAttachmentEntity.self)
            try context.delete(model: TicketEntity.self)
            try context.delete(model: ClientEntity.self)
            try context.delete(model: InventoryEventEntity.self)
            try context.delete(model: HardwareEntity.self)
            try context.delete(model: SyncMetadataEntity.self)
            try context.delete(model: PendingInventoryAdjustmentEntity.self)
            try context.save()
            await environment.syncEngine.syncAll()
        } catch {
            // swallow for now
        }
        isClearingCache = false
    }

    private func generateDiagnostics() -> String {
        let lines: [String] = [
            "Base URL: \(environment.configuration.baseURL)",
            "Channel: \(environment.configuration.buildChannel)",
            "Last Syncs: \(environment.syncEngine.lastSyncDates)",
            "Sync Error: \(environment.syncEngine.lastError ?? "none")"
        ]
        return lines.joined(separator: "\n")
    }
}
