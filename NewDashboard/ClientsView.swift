//
//  ClientsView.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//

import SwiftUI

struct ClientsView: View {
    @EnvironmentObject var api: APIClient
    @State private var clients: [ClientRecord] = []
    @State private var error: String?
    @State private var loading = false
    @State private var showNewClient = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                List(clients) { record in
                    NavigationLink {
                        ClientsDetailView(
                            record: record,
                            onUpdate: { updated in
                                if let idx = clients.firstIndex(where: { $0.client_key == updated.client_key }) {
                                    clients[idx] = updated
                                }
                            }
                        )
                    } label: {
                        HStack {
                            Text(record.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.white.opacity(0.82))
                        .shadow(color: Color.vipBlue.opacity(0.1), radius: 18, x: 0, y: 12)
                )
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .navigationTitle("Clients")
            .overlay {
                if loading && clients.isEmpty && error == nil { ProgressView() }
                if let e = error { Text(e).foregroundStyle(.red).padding(.horizontal) }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showNewClient = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("New Client")
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showNewClient) {
                NewClientSheet { created in
                    var next = clients
                    if let idx = next.firstIndex(where: { $0.client_key == created.client_key }) {
                        next[idx] = created
                    } else {
                        next.append(created)
                    }
                    clients = next.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                }
                .environmentObject(api)
            }
        }
        .vipScreenBackground()
    }

    @MainActor
    private func load() async {
        loading = true; defer { loading = false }
        do {
            clients = try await api.fetchClientsFlat()
            error = nil
        } catch let err {
            error = err.localizedDescription
        }
    }
}
