//
//  HardwareDetailView.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//


import SwiftUI

struct HardwareDetailView: View {
    @EnvironmentObject var api: APIClient
    
    @State var item: Hardware
    var onUpdate: (Hardware) -> Void
    
    @State private var descriptionText: String = ""
    @State private var barcodeText: String = ""
    @State private var salesPriceText: String = ""
    @State private var acquisitionCostText: String = ""
    @State private var vendorsText: String = ""   // comma-separated for editing
    
    @State private var showScanner = false
    @State private var saving = false
    @State private var error: String?
    
    var body: some View {
        Form {
            Section("Description") {
                TextField("Description", text: $descriptionText)
                    .textInputAutocapitalization(.never)
            }
            
            Section("Identifiers") {
                HStack {
                    TextField("Barcode", text: $barcodeText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                    Button { showScanner = true } label: {
                        Image(systemName: "barcode.viewfinder")
                    }
                    .accessibilityLabel("Scan barcode")
                }
                HStack { Text("ID"); Spacer(); Text("\(item.id)").foregroundStyle(.secondary) }
            }
            
            Section("Pricing") {
                TextField("Sales Price", text: $salesPriceText)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                
                TextField("Acquisition Cost", text: $acquisitionCostText)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                
                if let avg = item.average_unit_cost {
                    HStack {
                        Text("Average Unit Cost")
                        Spacer()
                        Text(String(format: "$%.2f", avg)).foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Vendors") {
                TextField("Comma-separated (e.g. Amazon, CDW)", text: $vendorsText)
                    .textInputAutocapitalization(.never)
            }
            
            if let error {
                Section { Text(error).foregroundStyle(.red) }
            }
            
            Section {
                Button {
                    Task { await save() }
                } label: {
                    Label("Save Changes", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(saving)
            }
        }
        .navigationTitle("Hardware")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadFields)
        .sheet(isPresented: $showScanner) {
            ScannerSheet { code in
                barcodeText = code
            }
        }
    }
    
    private func loadFields() {
        descriptionText = item.description
        barcodeText = item.barcode
        salesPriceText = item.sales_price.map { String(describing: $0) } ?? ""
        acquisitionCostText = item.acquisition_cost.map { String(describing: $0) } ?? ""
        vendorsText = (item.common_vendors ?? []).joined(separator: ", ")
    }
    
    private func buildPatch() -> [String: Any] {
        var patch: [String: Any] = [:]
        
        if descriptionText != item.description { patch["description"] = descriptionText }
        if barcodeText != item.barcode { patch["barcode"] = barcodeText }
        
        let salesTrim = salesPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldSales = item.sales_price.map { String(describing: $0) } ?? ""
        if salesTrim != oldSales { patch["sales_price"] = salesTrim.isEmpty ? NSNull() : salesTrim }
        
        let acqTrim = acquisitionCostText.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldAcq = item.acquisition_cost.map { String(describing: $0) } ?? ""
        if acqTrim != oldAcq { patch["acquisition_cost"] = acqTrim.isEmpty ? NSNull() : acqTrim }
        
        let newVendors = vendorsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if newVendors != (item.common_vendors ?? []) {
            patch["common_vendors"] = newVendors
        }
        
        return patch
    }
    
    private func save() async {
        await MainActor.run { error = nil }
        saving = true; defer { saving = false }
        
        let patch = buildPatch()
        if patch.isEmpty { return }
        
        do {
            let updated = try await api.updateHardware(id: item.id, patch: patch)
            await MainActor.run {
                self.item = updated
                self.onUpdate(updated)
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}
