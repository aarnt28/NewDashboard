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
            VStack(spacing: 24) {
                StartSection(
                    newType: $newType,
                    newClientKey: $newClientKey,
                    clients: clients,
                    isStarting: starting,
                    startAction: { await startNew() }
                )

                ActiveTicketsSection(
                    active: active,
                    onUpdate: replaceTicket,
                    onDelete: deleteTicket
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical)
            .navigationTitle("Active")
            .overlay(alignment: .bottom) {
                if loading && active.isEmpty && error == nil { ProgressView().padding() }
                if let e = error { Text(e).foregroundStyle(.red).padding() }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await refreshAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task { await refreshAll() }
            .refreshable { await refreshAll() }
        }
        .vipScreenBackground()
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
        } catch is CancellationError {
            return
        } catch let urlErr as URLError where urlErr.code == .cancelled {
            return
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
    let isStarting: Bool
    var startAction: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Start a new entry")
                .font(.headline)
                .foregroundStyle(Color.vipBlue)

            VStack(spacing: 12) {
                Picker("Type", selection: $newType) {
                    ForEach(EntryType.allCases, id: \.self) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                .pickerStyle(.menu)

                Picker("Client", selection: $newClientKey) {
                    ForEach(clients, id: \.client_key) { c in
                        Text(c.name).tag(c.client_key)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.95))
                    .shadow(color: Color.vipBlue.opacity(0.12), radius: 16, x: 0, y: 10)
            )

            Button {
                Task { await startAction() }
            } label: {
                if isStarting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Start", systemImage: "play.fill")
                        .labelStyle(.titleAndIcon)
                }
            }
            .buttonStyle(VIPProminentButtonStyle())
            .disabled(newClientKey.isEmpty || isStarting)
            .opacity(newClientKey.isEmpty ? 0.6 : 1)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(VIPTheme.primaryGradient, lineWidth: 1)
        )
        .shadow(color: Color.vipBlue.opacity(0.14), radius: 20, x: 0, y: 14)
    }
}

private struct ActiveTicketsSection: View {
    let active: [Ticket]
    var onUpdate: (Ticket) -> Void
    var onDelete: (Ticket) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.75))
                .shadow(color: Color.vipBlue.opacity(0.12), radius: 20, x: 0, y: 12)

            if active.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bolt.horizontal.fill")
                        .font(.title)
                        .foregroundStyle(Color.vipBlue.opacity(0.7))
                    Text("No active tickets yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(32)
            } else {
                List {
                    ForEach(active) { t in
                        NavigationLink {
                            TicketDetailView(ticket: t, onUpdate: onUpdate, onDelete: { onDelete(t) })
                        } label: {
                            TicketRow(ticket: t)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
