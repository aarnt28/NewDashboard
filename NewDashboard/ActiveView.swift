//
//  ActiveView.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//


import SwiftUI

struct ActiveView: View {
    @EnvironmentObject var api: APIClient
    
    @State private var newType: EntryType = .time
    @State private var newClientKey: String = ""
    @State private var clients: [ClientRecord] = []
    @State private var active: [Ticket] = []
    @State private var error: String?
    @State private var loading = false
    @State private var starting = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                
                StartSection(
                    newType: $newType,
                    newClientKey: $newClientKey,
                    clients: clients,
                    startAction: { await startNew() }
                )
                .frame(maxHeight: 260)
                
                ActiveTicketsSection(
                    active: active,
                    onUpdate: replaceTicket,
                    onDelete: deleteTicket
                )
            }
            .padding(.horizontal)
            .navigationTitle("Active")
            .overlay {
                if loading && active.isEmpty && error == nil { ProgressView() }
                if let e = error { Text(e).foregroundStyle(.red).padding(.horizontal) }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await refreshAll() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .task { await refreshAll() }
            .refreshable { await refreshAll() }
        }
    }
    
    // MARK: - Actions
    
    private func refreshAll() async {
        loading = true; defer { loading = false }
        do {
            async let cTask = api.fetchClientsFlat()
            async let aTask = api.listActiveTickets()
            let (c, a) = try await (cTask, aTask)
            await MainActor.run {
                clients = c
                active = a
                error = nil
                if newClientKey.isEmpty, let first = c.first { newClientKey = first.client_key }
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
    
    private func startNew() async {
        guard !newClientKey.isEmpty else { return }
        starting = true; defer { starting = false }
        do {
            let newTicket = try await api.startNew(clientKey: newClientKey, type: newType)
            await MainActor.run {
                active.insert(newTicket, at: 0)
                error = nil
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
    
    private func replaceTicket(_ updated: Ticket) {
        if let idx = active.firstIndex(where: { $0.id == updated.id }) {
            active[idx] = updated
        }
    }
    
    private func deleteTicket(_ ticket: Ticket) {
        Task {
            do {
                try await api.deleteTicket(id: ticket.id)
                await MainActor.run { active.removeAll { $0.id == ticket.id } }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }
}

// MARK: - Subviews

private struct StartSection: View {
    @Binding var newType: EntryType
    @Binding var newClientKey: String
    let clients: [ClientRecord]
    var startAction: () async -> Void
    
    var body: some View {
        Form {
            Section("Start") {
                Picker("Type", selection: $newType) {
                    ForEach(EntryType.allCases, id: \.self) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                Picker("Client", selection: $newClientKey) {
                    ForEach(clients, id: \.client_key) { c in
                        Text(c.name).tag(c.client_key)
                    }
                }
                Button("Start") { Task { await startAction() } }
                    .disabled(newClientKey.isEmpty)
            }
        }
    }
}

private struct ActiveTicketsSection: View {
    let active: [Ticket]
    var onUpdate: (Ticket) -> Void
    var onDelete: (Ticket) -> Void
    
    var body: some View {
        List {
            ForEach(active) { t in
                NavigationLink {
                    TicketDetailView(ticket: t, onUpdate: onUpdate, onDelete: { onDelete(t) })
                } label: {
                    TicketRow(ticket: t)
                }
            }
        }
    }
}
