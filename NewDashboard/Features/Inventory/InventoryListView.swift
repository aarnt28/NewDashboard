import SwiftUI
import SwiftData

struct InventoryListView: View {
    @ObservedObject private var environment: AppEnvironment
    @Query(sort: \HardwareEntity.name) private var hardware: [HardwareEntity]

    @Binding var selectedHardware: HardwareEntity?
    @StateObject private var viewModel: InventoryViewModel
    @State private var searchText: String = ""
    @State private var isSearchPresented = false
    @State private var isShowingScanner = false

    init(environment: AppEnvironment, selectedHardware: Binding<HardwareEntity?>) {
        self.environment = environment
        _selectedHardware = selectedHardware
        _viewModel = StateObject(wrappedValue: InventoryViewModel(environment: environment, context: environment.modelContainer.mainContext))
    }

    var body: some View {
        List {
            Section {
                Button {
                    isShowingScanner = true
                    viewModel.presentScanner()
                } label: {
                    Label("Scan Barcode", systemImage: "barcode.viewfinder")
                        .font(.headline)
                }
            }
            ForEach(filteredHardware, id: \.id) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.headline)
                        Text("Barcode: \(item.barcode)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Qty: \(item.quantityOnHand)")
                            .font(.title3)
                            .monospacedDigit()
                        if let last = item.lastInventoryEventAt {
                            Text(last, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedHardware = item
                    viewModel.activeHardware = item
                }
            }
        }
        .navigationTitle("Inventory")
        .searchable(text: $searchText, placement: .sidebar, isPresented: $isSearchPresented)
        .refreshable { await environment.syncEngine.sync(.hardware); await environment.syncEngine.sync(.inventoryEvents) }
        .sheet(isPresented: $isShowingScanner) {
            InventoryScannerView { code in
                viewModel.handleScan(code: code)
                isShowingScanner = false
            }
        }
        .sheet(item: Binding(get: { viewModel.activeHardware }, set: { viewModel.activeHardware = $0 })) { hardware in
            InventoryAdjustmentSheet(viewModel: viewModel, hardware: hardware)
        }
        .overlay(alignment: .top) {
            if let banner = viewModel.bannerMessage {
                BannerView(message: banner)
                    .padding()
            }
        }
        .onAppear {
            if viewModel.activeHardware == nil {
                selectedHardware = hardware.first
            }
        }
        .onChange(of: viewModel.activeHardware) { newValue in
            if let hardware = newValue {
                selectedHardware = hardware
            }
        }
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Find") { isSearchPresented = true }
                    .keyboardShortcut("f", modifiers: .command)
            }
        }
    }

    private var filteredHardware: [HardwareEntity] {
        guard !searchText.isEmpty else { return hardware }
        return hardware.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText) || item.barcode.localizedCaseInsensitiveContains(searchText)
        }
    }
}

private struct BannerView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text(message)
                .font(.footnote)
        }
        .padding(10)
        .background(.thinMaterial, in: Capsule())
        .shadow(radius: 4)
    }
}

struct InventoryAdjustmentSheet: View {
    @ObservedObject var viewModel: InventoryViewModel
    @ObservedObject var hardware: HardwareEntity
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Hardware") {
                    Text(hardware.name)
                    Text("Current balance: \(hardware.quantityOnHand)")
                        .foregroundStyle(.secondary)
                }
                Section("Adjustment") {
                    Stepper(value: $viewModel.adjustmentQuantity, in: -100...100) {
                        Text("Quantity change: \(viewModel.adjustmentQuantity)")
                    }
                    TextField("Note", text: $viewModel.note)
                }
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Adjust Inventory")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        viewModel.submitAdjustment()
                        dismiss()
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                        } else {
                            Text("Submit")
                        }
                    }
                    .disabled(viewModel.isSubmitting)
                }
            }
        }
    }
}
