import SwiftUI

struct UseInventoryView: View {
    @EnvironmentObject var api: APIClient
    
    // Data
    @State private var clients: [ClientRecord] = []
    @State private var selectedClientKey: String = ""
    @State private var barcode: String = ""
    @State private var quantity: Int = 1
    @State private var notes: String = ""
    @State private var salesPrice: String = ""
    
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
                
                Section("Client") {
                    if clients.isEmpty {
                        ProgressView("Loading clients…")
                            .task { await loadClients() }
                    } else {
                        Picker("Client", selection: $selectedClientKey) {
                            ForEach(clients, id: \.client_key) { c in
                                Text(c.name).tag(c.client_key)
                            }
                        }
                    }
                }
                
                Section("Price") {
                    TextField("Sales Price (e.g. 49.99)", text: $salesPrice)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                
                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Use Inventory")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if loading {
                            ProgressView()
                        } else {
                            Text("Create Ticket")
                        }
                    }
                    .disabled(loading || barcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedClientKey.isEmpty)
                }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerUIKit { code in
                    self.barcode = code
                    self.showScanner = false
                }
            }
            .alert("Ticket Created", isPresented: $presentSuccess) {
                Button("OK") { presentSuccess = false; dismiss() }
            } message: {
                Text(successTicketID.map { "Ticket #\($0) created." } ?? "Created.")
            }
        }
    }
    
    @MainActor
    private func loadClients() async {
        do {
            self.clients = try await api.fetchClientsFlat()
            if selectedClientKey.isEmpty, let first = clients.first {
                selectedClientKey = first.client_key
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    @MainActor
    private func submit() async {
        error = nil
        guard !barcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Please scan or enter a barcode."
            return
        }
        guard !selectedClientKey.isEmpty else {
            error = "Select a client."
            return
        }
        loading = true; defer { loading = false }
        
        // Build ticket payload using the server's expected fields
        let new = NewTicket(
            client_key: selectedClientKey,
            entry_type: .hardware,
            start_iso: ISO8601DateTransformer.string(Date()),
            end_iso: nil,
            note: notes,
            invoice_number: nil,
            sent: nil,
            completed: nil,
            hardware_id: nil,
            hardware_barcode: barcode.trimmingCharacters(in: .whitespacesAndNewlines),
            hardware_quantity: quantity,
            hardware_description: nil,
            hardware_sales_price: salesPrice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : salesPrice.trimmingCharacters(in: .whitespacesAndNewlines),
            flat_rate_amount: nil,
            flat_rate_quantity: nil,
            invoiced_total: nil
        )
        
        do {
            let ticket = try await api.createTicket(new)
            self.successTicketID = ticket.id
            self.presentSuccess = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
