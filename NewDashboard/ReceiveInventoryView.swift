//
//  ReceiveInventoryView.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//


import SwiftUI

struct ReceiveInventoryView: View {
    @EnvironmentObject var api: APIClient
    
    // Data
    @State private var barcode: String = ""
    @State private var quantity: Int = 1
    @State private var acquisitionCost: String = ""
    @State private var vendor: String = ""
    @State private var notes: String = ""
    
    // UI
    @Environment(\.dismiss) private var dismiss
    @State private var loading = false
    @State private var error: String?
    @State private var successTicketID: Int?
    @State private var showScanner = false
    @State private var presentSuccess = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Scan / Enter Barcode") {
                    HStack {
                        TextField("Barcode", text: $barcode)
                            .textInputAutocapitalization(.never)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            showScanner = true
                        } label: {
                            Label("Scan", systemImage: "barcode.viewfinder")
                        }
                        .accessibilityLabel("Scan barcode")
                    }
                    Stepper(value: $quantity, in: 1...999) {
                        HStack {
                            Text("Quantity")
                            Spacer()
                            Text("\(quantity)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Receiving Details") {
                    TextField("Acquisition Cost (e.g. 39.95)", text: $acquisitionCost)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                    TextField("Vendor (optional)", text: $vendor)
                        .textInputAutocapitalization(.never)
                }
                
                
                Section("Notes") {
                    TextEditor(text: $notes).frame(minHeight: 80)
                }
                
                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("Receive Inventory")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await submit() } } label: {
                        loading ? AnyView(ProgressView()) : AnyView(Text("Create Ticket"))
                    }
                    .disabled(loading || barcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty )
                }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerUIKit { code in
                    barcode = code
                    showScanner = false
                }
            }
            .alert("Ticket Created", isPresented: $presentSuccess) {
                Button("OK") { presentSuccess = false; dismiss() }
            } message: {
                Text("Inventory received successfully.")
            }
        }
    }
    
    @MainActor
    private func submit() async {
        error = nil
        guard !barcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Please scan or enter a barcode."; return
        }
        loading = true; defer { loading = false }
        
        do {
            _ = try await api.receiveInventory(
                barcode: barcode.trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: quantity,
                acquisitionCost: acquisitionCost,
                vendor: vendor
            )
            self.successTicketID = nil
            self.presentSuccess = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
