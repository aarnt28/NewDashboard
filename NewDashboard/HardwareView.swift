import SwiftUI

struct HardwareView: View {
    @EnvironmentObject var api: APIClient
    @State private var items: [Hardware] = []
    @State private var total: Int = 0
    @State private var error: String?
    @State private var loading = false
    @State private var pageSize = 50
    @State private var offset = 0
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var showNewHardware = false
    @State private var showUseInventory = false
    @State private var showReceiveInventory = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                SummaryCard(total: total)

                hardwareList
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .navigationTitle("Hardware")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    actionsMenu
                }
            }
            .overlay {
                if loading && items.isEmpty { ProgressView() }
            }
            .overlay(alignment: .top) {
                if let e = error { Text(e).foregroundStyle(.red).padding() }
            }
            .task { await load(reset: true) }
            .refreshable { await load(reset: true) }
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

    @ViewBuilder
    private var hardwareList: some View {
        List {
            ForEach(items) { h in
                NavigationLink(destination: HardwareDetailView(item: h) { updated in
                    if let idx = items.firstIndex(where: { $0.id == updated.id }) {
                        items[idx] = updated
                    }
                }) {
                    HardwareRow(h: h)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.adaptiveRow)
                .onAppear { loadMoreIfNeeded(currentItem: h) }
            }

            if isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 8)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
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

    private var actionsMenu: some View {
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

    @MainActor
    private func load(reset: Bool) async {
        if reset {
            if loading { return }
            loading = true
            offset = 0
            hasMore = true
            items.removeAll()
        } else {
            if isLoadingMore || loading || !hasMore { return }
            isLoadingMore = true
        }

        let currentOffset = reset ? 0 : offset

        do {
            let res = try await api.listHardware(limit: pageSize, offset: currentOffset)
            let fetched = res.items

            items.append(contentsOf: fetched)
            offset = currentOffset + fetched.count

            if let totalValue = res.total {
                total = totalValue
                hasMore = offset < totalValue
            } else {
                total = max(total, offset)
                hasMore = fetched.count == pageSize
            }

            error = nil
        } catch let err {
            if reset {
                total = 0
            }
            error = err.localizedDescription
        }

        if reset {
            loading = false
        } else {
            isLoadingMore = false
        }
    }

    private func loadMoreIfNeeded(currentItem: Hardware) {
        guard hasMore,
              !loading,
              !isLoadingMore,
              let last = items.last,
              last.id == currentItem.id else { return }

        Task { await load(reset: false) }
    }
}

private struct HardwareRow: View {
    let h: Hardware

    private var qohValue: Int? { h.quantity_on_hand }
    private var committedValue: Int { h.quantity_committed ?? 0 }
    private var reservedValue: Int { h.quantity_reserved ?? 0 }
    private var availableValue: Int? {
        if let qoh = qohValue {
            if let provided = h.quantity_available { return provided }
            return max(0, qoh - committedValue)
        }
        return nil
    }

    private var statusText: String? {
        guard let qoh = qohValue else { return nil }
        let available = availableValue ?? 0
        if available > 0 { return "In stock" }
        if qoh > 0 { return "Allocated" }
        return "Out of stock"
    }

    private var statusColor: Color {
        guard let qoh = qohValue else { return .secondary }
        let available = availableValue ?? 0
        if available > 0 { return .green }
        if qoh > 0 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(h.description)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            HStack(spacing: 8) {
                if let qoh = qohValue {
                    if let text = statusText {
                        Text(text)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(statusColor)
                    }
                    Text("QOH: \(qoh)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if reservedValue > 0 {
                        Text("Reserved: \(reservedValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if committedValue > 0 {
                        Text("Committed: \(committedValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    let avail = max(0, availableValue ?? 0)
                    Text("Avail: \(avail)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(h.barcode)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
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

