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
    @State private var showScanner = false
    @State private var presentSuccess = false
    @State private var successTitle: String = ""
    @State private var successMessage: String = ""
    
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
            .alert(successTitle.isEmpty ? "Inventory Received" : successTitle, isPresented: $presentSuccess) {
                Button("OK") { presentSuccess = false; dismiss() }
            } message: {
                Text(successMessage.isEmpty ? "Inventory received successfully." : successMessage)
            }
        }
    }

    @MainActor
    private func submit() async {
        error = nil
        successTitle = ""
        successMessage = ""
        guard !barcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Please scan or enter a barcode."; return
        }
        loading = true; defer { loading = false }
        
        do {
            let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let response = try await api.receiveInventory(
                barcode: trimmedBarcode,
                quantity: quantity,
                acquisitionCost: acquisitionCost,
                vendor: vendor,
                note: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            let content = successContent(from: response)
            self.successTitle = content.title
            self.successMessage = content.message
            self.presentSuccess = true
            self.barcode = ""
            self.quantity = 1
            self.acquisitionCost = ""
            self.vendor = ""
            self.notes = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func successContent(from response: APIClient.InventoryReceiveResponse) -> (title: String, message: String) {
        if let ticketID = response.ticket?.id ?? response.ticketId {
            return ("Ticket Created", "Ticket #\(ticketID) created.")
        }

        if let adjustment = response.adjustment {
            if let description = adjustment.description, !description.isEmpty {
                return ("Inventory Adjusted", description)
            }

            if let message = adjustment.message, !message.isEmpty {
                return ("Inventory Adjusted", message)
            }

            if let note = adjustment.note, !note.isEmpty {
                return ("Inventory Adjusted", note)
            }

            if let change = adjustment.quantityChange, let newQuantity = adjustment.newQuantity {
                return ("Inventory Adjusted", "Adjusted by \(change) to \(newQuantity).")
            }

            if let previous = adjustment.previousQuantity, let newQuantity = adjustment.newQuantity {
                return ("Inventory Adjusted", "Quantity changed from \(previous) to \(newQuantity).")
            }

            if let quantity = adjustment.quantity {
                let unit = quantity == 1 ? "item" : "items"
                if let barcode = adjustment.barcode, !barcode.isEmpty {
                    return ("Inventory Adjusted", "Received \(quantity) \(unit) for \(barcode).")
                }
                return ("Inventory Adjusted", "Received \(quantity) \(unit).")
            }
        }

        if let message = response.message, !message.isEmpty {
            return ("Inventory Received", message)
        }

        return ("Inventory Received", "Inventory received successfully.")
    }
}
