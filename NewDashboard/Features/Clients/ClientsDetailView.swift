//
//  ClientsDetailView.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//


import SwiftUI

struct ClientsDetailView: View {
    @EnvironmentObject var api: APIClient
    
    let record: ClientRecord
    var onUpdate: (ClientRecord) -> Void
    
    // Editable fields
    @State private var name: String = ""
    @State private var rows: [AttrRow] = []     // editable k/v pairs
    @State private var newKey: String = ""
    @State private var newValue: String = ""
    
    @State private var saving = false
    @State private var error: String?
    
    struct AttrRow: Identifiable, Hashable {
        var id = UUID()
        var key: String
        var value: String
        var originalValue: String?
    }
    
    var body: some View {
        Form {
            Section("Identity") {
                HStack {
                    Text("Client Key")
                    Spacer()
                    Text(record.client_key).foregroundStyle(.secondary)
                }
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
            }
            
            Section("Attributes") {
                if rows.isEmpty {
                    Text("No attributes").foregroundStyle(.secondary)
                } else {
                    ForEach($rows) { $row in
                        HStack {
                            Text(row.key)
                                .font(.callout)
                            Spacer()
                            TextField("value", text: $row.value)
                                .textInputAutocapitalization(.never)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.primary)
                        }
                    }
                    .onDelete { indexSet in
                        // “Delete” means clear value (sends NSNull on save)
                        for i in indexSet { rows[i].value = "" }
                    }
                }
                
                VStack(spacing: 8) {
                    HStack {
                        TextField("new key", text: $newKey)
                            .textInputAutocapitalization(.never)
                        TextField("new value", text: $newValue)
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                    }
                    Button {
                        addNew()
                    } label: {
                        Label("Add Attribute", systemImage: "plus.circle")
                    }
                    .disabled(newKey.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            
            if let e = error {
                Section { Text(e).foregroundStyle(.red) }
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
        .navigationTitle("Client")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadFields)
    }
    
    private func loadFields() {
        name = record.name
        // Build editable rows from attributes map; hide "name" if it leaked in
        let attrs = record.attributes ?? [:]
        rows = attrs
            .filter { $0.key != "name" }
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { AttrRow(key: $0.key, value: $0.value, originalValue: $0.value) }
    }
    
    private func addNew() {
        let k = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let v = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return }
        // if key already exists, just update its value in-place
        if let idx = rows.firstIndex(where: { $0.key.caseInsensitiveCompare(k) == .orderedSame }) {
            rows[idx].value = v
        } else {
            rows.append(AttrRow(key: k, value: v, originalValue: nil))
        }
        newKey = ""; newValue = ""
    }
    
    private func buildPatch() -> [String: Any] {
        var patch: [String: Any] = [:]
        
        if name != record.name {
            patch["name"] = name
        }
        
        // Only send changed attributes; empty value => clear (NSNull)
        let original = record.attributes ?? [:]
        for row in rows {
            let newVal = row.value.trimmingCharacters(in: .whitespacesAndNewlines)
            let oldVal = original[row.key]
            if newVal.isEmpty {
                if oldVal != nil { patch[row.key] = NSNull() }
            } else if oldVal == nil || oldVal != newVal {
                patch[row.key] = newVal
            }
        }
        
        return patch
    }
    
    private func save() async {
        await MainActor.run { error = nil }
        saving = true; defer { saving = false }
        
        let patch = buildPatch()
        if patch.isEmpty { return } // nothing to change
        
        do {
            let updated = try await api.updateClient(clientKey: record.client_key, patch: patch)
            
            // Convert server blob back into our flat UI model
            let updatedAttrs = updated.attributes ?? [:]
            let flat = ClientRecord(
                client_key: updated.client_key,
                name: updated.name,
                attributes: updatedAttrs.isEmpty ? nil : updatedAttrs
            )
            await MainActor.run {
                onUpdate(flat)
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}
