import SwiftUI

struct HardwareView: View {
    @EnvironmentObject var api: APIClient
    @State private var items: [Hardware] = []
    @State private var total: Int = 0
    @State private var error: String?
    @State private var loading = false
    @State private var showNewHardware = false
    @State private var showUseInventory = false
    @State private var showReceiveInventory = false
    
    var body: some View {
        NavigationStack {
            List(items) { h in
                NavigationLink {
                    HardwareDetailView(item: h) { updated in
                        if let idx = items.firstIndex(where: { $0.id == updated.id }) {
                            items[idx] = updated
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(h.description)
                            .font(.headline)
                            .lineLimit(2)
                        
                        Text(h.barcode)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Hardware")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showUseInventory = true } label: {
                            Label("Use Inventory", systemImage: "square.and.arrow.down")
                        }
                        Button { showReceiveInventory = true } label: {
                            Label("Receive Inventory", systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        Button { showNewHardware = true } label: {
                            Label("New Hardware", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showUseInventory) {
                UseInventoryView()
                    .environmentObject(api)
            }
            .sheet(isPresented: $showReceiveInventory) {
                ReceiveInventoryView()
                    .environmentObject(api)
            }
            .sheet(isPresented: $showNewHardware) {
                NewHardwareSheet { created in
                    items.insert(created, at: 0)
                }
                    .environmentObject(api)
            }
            .sheet(isPresented: $showNewHardware) {
                NewHardwareSheet { created in
                    // Simple prepend on create
                    items.insert(created, at: 0)
                }
                .environmentObject(api)
            }
        }
    }
    
    @MainActor
    private func load() async {
        loading = true; defer { loading = false }
        do {
            let res = try await api.listHardware(limit: 200, offset: 0)
            items = res.items
            total = res.total ?? res.items.count
            error = nil
        } catch let err {
            error = err.localizedDescription
        }
    }
}
//
//  HardwareView.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//


import SwiftUI

struct HardwareView: View {
    @EnvironmentObject var api: APIClient
    @State private var items: [Hardware] = []
    @State private var total: Int = 0
    @State private var error: String?
    @State private var loading = false
    @State private var showNewHardware = false
    @State private var showUseInventory = false
    @State private var showReceiveInventory = false
    
    var body: some View {
        NavigationStack {
            List(items) { h in
                NavigationLink {
                    HardwareDetailView(item: h) { updated in
                        if let idx = items.firstIndex(where: { $0.id == updated.id }) {
                            items[idx] = updated
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(h.description)
                            .font(.headline)
                            .lineLimit(2)
                        
                        Text(h.barcode)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Hardware")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showUseInventory = true } label: {
                            Label("Use Inventory", systemImage: "square.and.arrow.down")
                        }
                        Button { showReceiveInventory = true } label: {
                            Label("Receive Inventory", systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        Button { showNewHardware = true } label: {
                            Label("New Hardware", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showUseInventory) {
                UseInventoryView()
                    .environmentObject(api)
            }
            .sheet(isPresented: $showReceiveInventory) {
                ReceiveInventoryView()
                    .environmentObject(api)
            }
            .sheet(isPresented: $showNewHardware) {
                NewHardwareSheet { created in
                    items.insert(created, at: 0)
                }
                    .environmentObject(api)
            }
            .sheet(isPresented: $showNewHardware) {
                NewHardwareSheet { created in
                    // Simple prepend on create
                    items.insert(created, at: 0)
                }
                .environmentObject(api)
            }
        }
    }
    
    @MainActor
    private func load() async {
        loading = true; defer { loading = false }
        do {
            let res = try await api.listHardware(limit: 200, offset: 0)
            items = res.items
            total = res.total ?? res.items.count
            error = nil
        } catch let err {
            error = err.localizedDescription
        }
    }
}
