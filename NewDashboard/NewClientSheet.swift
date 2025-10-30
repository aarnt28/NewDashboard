//
//  NewClientSheet.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//


import SwiftUI

struct NewClientSheet: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss
    
    var onCreate: (ClientRecord) -> Void
    
    // Standard fields (required + recommended)
    @State private var clientKey = ""
    @State private var name = ""
    @State private var displayName = ""
    @State private var supportRate = ""   // keep as string to match API examples
    @State private var contract = false   // Yes/No via Picker
    
    // Simple key/value entry for optional custom attributes
    @State private var attrKey = ""
    @State private var attrValue = ""
    @State private var attrs: [String: String] = [:]   // custom-only (NOT standard keys)
    
    @State private var saving = false
    @State private var error: String?
    
    private let reservedKeys: Set<String> = ["name", "display_name", "support_rate", "contract"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Client Key (unique id)", text: $clientKey)
                        .textInputAutocapitalization(.never)
                    TextField("Name (full company name)", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Display Name (short label)", text: $displayName)
                        .textInputAutocapitalization(.words)
                }
                
                Section("Billing / Contract") {
                    TextField("Support Rate (e.g. 135)", text: $supportRate)
                        .keyboardType(.decimalPad)
                    
                    Picker("Contract", selection: $contract) {
                        Text("No").tag(false)
                        Text("Yes").tag(true)
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Custom Attributes (optional)") {
                    if attrs.isEmpty {
                        Text("No custom attributes").foregroundStyle(.secondary)
                    } else {
                        ForEach(attrs.keys.sorted(), id: \.self) { k in
                            HStack {
                                Text(k)
                                Spacer()
                                Text(attrs[k] ?? "").foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { indexSet in
                            for i in indexSet {
                                let k = attrs.keys.sorted()[i]
                                attrs.removeValue(forKey: k)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("key (e.g. timezone)", text: $attrKey)
                            .textInputAutocapitalization(.never)
                        TextField("value (e.g. CST)", text: $attrValue)
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                        Button { addAttr() } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(!canAddAttr)
                    }
                    .onSubmit(addAttr)
                }
                
                if let e = error {
                    Section { Text(e).foregroundStyle(.red) }
                }
            }
            .navigationTitle("New Client")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .disabled(!canCreate || saving)
                }
            }
        }
    }
    
    private var canCreate: Bool {
        !clientKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var canAddAttr: Bool {
        let k = attrKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !k.isEmpty && !reservedKeys.contains(k)
    }
    
    private func addAttr() {
        let k = attrKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let v = attrValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty, !reservedKeys.contains(k) else { return }
        attrs[k] = v
        attrKey = ""; attrValue = ""
    }
    
    private func create() async {
        saving = true; defer { saving = false }
        error = nil
        
        // Build payload in the documented shape
        var clientObj: [String: Any] = [
            "name": name,
            "display_name": displayName,
            "support_rate": supportRate,
            "contract": contract
        ]
        
        // Merge custom attributes (avoid reserved keys)
        for (k, v) in attrs where !reservedKeys.contains(k) {
            clientObj[k] = v
        }
        
        do {
            let created = try await api.createClientV2(
                clientKey: clientKey,
                clientObject: clientObj
            )
            onCreate(created)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
