import SwiftUI
import SwiftData

struct RootShellView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.modelContext) private var context

    @State private var sidebarSelection: SidebarItem? = .tickets
    @State private var selectedTicket: TicketEntity?
    @State private var selectedClient: ClientEntity?
    @State private var selectedHardware: HardwareEntity?
    @State private var showingSettings = false
    @State private var showingAPIKeyPrompt = false

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
        } content: {
            contentView
        } detail: {
            detailView
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(environment)
        }
        .sheet(isPresented: $showingAPIKeyPrompt, onDismiss: reloadAuthenticationState) {
            APIKeyEntryView()
                .environmentObject(environment)
        }
        .task(id: environment.authenticationState) {
            showingAPIKeyPrompt = {
                if case .needsAPIKey = environment.authenticationState {
                    return true
                } else {
                    return false
                }
            }()
        }
    }

    private var sidebar: some View {
        List(selection: $sidebarSelection) {
            Section("Workspace") {
                Label("Tickets", systemImage: "ticket")
                    .tag(SidebarItem.tickets)
                Label("Clients", systemImage: "person.2")
                    .tag(SidebarItem.clients)
                Label("Inventory", systemImage: "shippingbox")
                    .tag(SidebarItem.inventory)
            }
        }
        .navigationTitle("NewDashboard")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: environment.refreshAll) {
                    if environment.isSyncing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                .help("Refresh now")

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Open Settings")
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch sidebarSelection ?? .tickets {
        case .tickets:
            TicketsListView(selectedTicket: $selectedTicket, selectedClient: $selectedClient)
                .environmentObject(environment)
        case .clients:
            ClientsListView(selectedClient: $selectedClient)
                .environmentObject(environment)
        case .inventory:
            InventoryListView(environment: environment, selectedHardware: $selectedHardware)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch sidebarSelection ?? .tickets {
        case .tickets:
            if let ticket = selectedTicket {
                TicketDetailView(ticket: ticket)
                    .environmentObject(environment)
            } else {
                placeholder(text: "Select a ticket to view its details")
            }
        case .clients:
            if let client = selectedClient {
                ClientDetailView(client: client)
            } else {
                placeholder(text: "Select a client to view more details")
            }
        case .inventory:
            if let hardware = selectedHardware {
                HardwareDetailView(hardware: hardware)
            } else {
                placeholder(text: "Select hardware to see its balance and history")
            }
        }
    }

    private func placeholder(text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "square.dashed")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func reloadAuthenticationState() {
        Task { await environment.authenticationController.bootstrap() }
    }
}

enum SidebarItem: Hashable {
    case tickets
    case clients
    case inventory
}
