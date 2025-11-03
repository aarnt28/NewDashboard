//
//  NewHardwareSheet.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//


import SwiftUI

struct NewHardwareSheet: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss
    
    var onCreate: (Hardware) -> Void
    
    @State private var descriptionText = ""
    @State private var barcodeText = ""
    @State private var salesPriceText = ""
    @State private var acquisitionCostText = ""
    @State private var vendorsText = ""
    
    @State private var showScanner = false
    @State private var saving = false
    @State private var error: String?
    
    var body: some View {
        NavigationStack {
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
                }
                
                Section("Pricing") {
                    TextField("Sales Price", text: $salesPriceText)
                        .keyboardType(.decimalPad)
                    TextField("Acquisition Cost", text: $acquisitionCostText)
                        .keyboardType(.decimalPad)
                }
                
                Section("Vendors") {
                    TextField("Comma-separated (e.g. Amazon, CDW)", text: $vendorsText)
                        .textInputAutocapitalization(.never)
                }
                
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("New Hardware")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .disabled(descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving)
                }
            }
            .sheet(isPresented: $showScanner) {
                ScannerSheet { code in barcodeText = code }
            }
        }
    }
    
    private func create() async {
        saving = true; defer { saving = false }
        error = nil
        
        var payload: [String: Any] = [
            "description": descriptionText,
            "barcode": barcodeText
        ]
        
        let sp = salesPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sp.isEmpty { payload["sales_price"] = sp }
        
        let ac = acquisitionCostText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !ac.isEmpty { payload["acquisition_cost"] = ac }
        
        let vendors = vendorsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !vendors.isEmpty { payload["common_vendors"] = vendors }
        
        do {
            let created = try await api.createHardware(payload)
            onCreate(created)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
