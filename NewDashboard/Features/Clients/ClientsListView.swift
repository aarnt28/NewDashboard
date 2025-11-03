import SwiftUI
import SwiftData

struct ClientsListView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.modelContext) private var context
    @Query(sort: \ClientEntity.name) private var clients: [ClientEntity]

    @Binding var selectedClient: ClientEntity?
    @State private var searchText: String = ""
    @State private var isSearchPresented = false

    private var filteredClients: [ClientEntity] {
        guard !searchText.isEmpty else { return clients }
        return clients.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        List {
            ForEach(filteredClients, id: \.id) { client in
                VStack(alignment: .leading, spacing: 4) {
                    Text(client.name)
                        .font(.headline)
                    if let email = client.email {
                        Label(email, systemImage: "envelope")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let phone = client.phone {
                        Label(phone, systemImage: "phone")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture { selectedClient = client }
            }
        }
        .searchable(text: $searchText, placement: .sidebar, isPresented: $isSearchPresented)
        .refreshable { await environment.syncEngine.sync(.clients) }
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Find") { isSearchPresented = true }
                    .keyboardShortcut("f", modifiers: .command)
            }
        }
    }
}

struct ClientDetailView: View {
    @ObservedObject var client: ClientEntity

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if !client.customAttributes.isEmpty {
                    attributesSection
                }
                ticketsSection
            }
            .padding()
        }
        .navigationTitle(client.name)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let email = client.email {
                Label(email, systemImage: "envelope")
            }
            if let phone = client.phone {
                Label(phone, systemImage: "phone")
            }
            Text("Updated \(client.updatedAt.formatted(.relative(presentation: .named)))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var attributesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Attributes")
                .font(.headline)
            ForEach(client.customAttributes.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                HStack {
                    Text(key)
                        .fontWeight(.medium)
                    Spacer()
                    Text(value)
                        .foregroundStyle(.secondary)
                }
                Divider()
            }
        }
    }

    private var ticketsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tickets")
                .font(.headline)
            if client.tickets.isEmpty {
                Text("No tickets yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(client.tickets.sorted(by: { $0.updatedAt > $1.updatedAt }), id: \.id) { ticket in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ticket.title)
                            .font(.subheadline)
                        Text(ticket.status.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                }
            }
        }
    }
}
