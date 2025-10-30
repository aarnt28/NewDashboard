//
//  TicketsScreen.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//


import SwiftUI

struct TicketsScreen: View {
    @EnvironmentObject var api: APIClient

    @State private var tickets: [Ticket] = []
    @State private var error: String?
    @State private var loading = false

    var body: some View {
        NavigationStack {
            List(tickets) { t in
                NavigationLink {
                    TicketDetailView(ticket: t, onUpdate: replaceTicket, onDelete: { deleteTicket(t) })
                } label: {
                    TicketRow(ticket: t)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Recent Tickets")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await reload() } } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(loading)
                }
            }
            .overlay {
                if loading && tickets.isEmpty { ProgressView() }
                if let e = error { Text(e).foregroundStyle(.red).padding() }
            }
            .task { await reload() }
            .refreshable { await reload() }
        }
    }

    @MainActor
    private func reload() async {
        loading = true; defer { loading = false }
        do {
            tickets = try await api.listTickets()
            error = nil
        } catch let err {
            error = err.localizedDescription
        }
    }

    private func replaceTicket(_ updated: Ticket) {
        if let idx = tickets.firstIndex(where: { $0.id == updated.id }) {
            tickets[idx] = updated
        }
    }

    private func deleteTicket(_ t: Ticket) {
        Task {
            do {
                try await api.deleteTicket(id: t.id)
                await MainActor.run { tickets.removeAll { $0.id == t.id } }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }
}
