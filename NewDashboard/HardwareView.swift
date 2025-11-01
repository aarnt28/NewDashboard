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
            VStack(spacing: 20) {
                SummaryCard(total: total)

                List(items) { h in
                    NavigationLink {
                        HardwareDetailView(item: h) { updated in
                            if let idx = items.firstIndex(where: { $0.id == updated.id }) {
                                items[idx] = updated
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(h.description)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            Text(h.barcode)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
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
            .overlay {
                if loading && items.isEmpty { ProgressView() }
                if let e = error { Text(e).foregroundStyle(.red).padding() }
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
        }
        .vipScreenBackground()
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

private struct SummaryCard: View {
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Tracked hardware", systemImage: "shippingbox")
                .font(.headline)
                .foregroundStyle(.white)
            Text("\(total)")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Total assets in inventory")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(VIPTheme.cardGradient)
                .shadow(color: Color.vipBlue.opacity(0.2), radius: 18, x: 0, y: 12)
        )
    }
}
