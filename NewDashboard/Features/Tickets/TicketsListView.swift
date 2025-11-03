import SwiftUI
import SwiftData

struct TicketsListView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.modelContext) private var context
    @Query(sort: \TicketEntity.updatedAt, order: .reverse) private var tickets: [TicketEntity]

    @Binding var selectedTicket: TicketEntity?
    @Binding var selectedClient: ClientEntity?

    @State private var searchText: String = ""
    @State private var statusFilter: TicketDTO.Status? = nil
    @State private var isSearchPresented = false
    @State private var isPresentingEditor = false

    private var filteredTickets: [TicketEntity] {
        tickets.filter { ticket in
            matchesSearch(ticket) && matchesStatus(ticket)
        }
    }

    var body: some View {
        List {
            ForEach(filteredTickets, id: \.id) { ticket in
                TicketRowView(ticket: ticket)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTicket = ticket
                        selectedClient = ticket.client
                    }
            }
            .onDelete(perform: deleteTickets)
        }
        .overlay(alignment: .bottomTrailing) {
            if let error = environment.syncEngine.lastError {
                InlineErrorBanner(message: error)
                    .padding()
            }
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: Text("Search tickets"), isPresented: $isSearchPresented)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker("Status", selection: $statusFilter) {
                        Text("All statuses").tag(TicketDTO.Status?.none)
                        ForEach(TicketDTO.Status.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized).tag(TicketDTO.Status?.some(status))
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .help("Filter tickets")

                Button {
                    isPresentingEditor = true
                } label: {
                    Label("New Ticket", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            ToolbarItem(placement: .keyboard) {
                Button("Find") {
                    isSearchPresented = true
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }
        .refreshable { await environment.syncEngine.sync(.tickets) }
        .sheet(isPresented: $isPresentingEditor) {
            TicketEditorView(ticket: nil)
                .environmentObject(environment)
        }
    }

    private func deleteTickets(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filteredTickets[index])
        }
        try? context.save()
    }

    private func matchesSearch(_ ticket: TicketEntity) -> Bool {
        guard !searchText.isEmpty else { return true }
        let haystack = [ticket.title, ticket.number, ticket.client?.name ?? "", ticket.details ?? ""]
            .joined(separator: " ")
            .lowercased()
        return haystack.contains(searchText.lowercased())
    }

    private func matchesStatus(_ ticket: TicketEntity) -> Bool {
        guard let statusFilter else { return true }
        return ticket.status == statusFilter
    }
}

struct TicketRowView: View {
    let ticket: TicketEntity

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("#\(ticket.number)")
                        .font(.callout)
                        .fontWeight(.medium)
                    Text(ticket.status.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ticket.status.badgeColor.opacity(0.15))
                        .clipShape(Capsule())
                        .foregroundStyle(ticket.status.badgeColor)
                }
                Text(ticket.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let client = ticket.client {
                    Text(client.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let details = ticket.details, !details.isEmpty {
                    Text(details)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if let assignee = ticket.assignee {
                    Label(assignee, systemImage: "person.crop.circle")
                        .labelStyle(.titleAndIcon)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text(ticket.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct InlineErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(.footnote)
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(Color.orange.gradient)
        .clipShape(Capsule())
        .shadow(radius: 4)
    }
}

private extension TicketDTO.Status {
    var badgeColor: Color {
        switch self {
        case .open: return .blue
        case .pending: return .orange
        case .resolved: return .green
        case .closed: return .gray
        }
    }
}
