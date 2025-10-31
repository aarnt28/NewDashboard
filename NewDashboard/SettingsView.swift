import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var api: APIClient

    // UI holds text; convert to URL on Apply
    @State private var tmpURL: String = ""
    @State private var tmpKey: String = ""
    @State private var info: String?

    var body: some View {
        Form {
            Section("Server") {
                TextField("Base URL (https://…)", text: $tmpURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .textContentType(.URL)

                TextField("X-API-Key", text: $tmpKey)
                    .textInputAutocapitalization(.never)
                    .textContentType(.password)

                Button("Apply") { applySettings() }
            }

            if let info {
                Section { Text(info).foregroundStyle(.secondary) }
            }

            Section("Tips") {
                Text("""
                     Use your public HTTPS host (Cloudflare proxy, Full-Strict).
                     Example: https://tracker.turnernet.co
                     On iPad, localhost won’t work.
                     """)
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            tmpURL = api.baseURL.absoluteString
            tmpKey = api.apiKey
        }
    }

    private func applySettings() {
        var text = tmpURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty, !text.lowercased().hasPrefix("http") {
            text = "https://" + text
        }
        guard let url = URL(string: text) else {
            info = "Invalid URL."
            return
        }
        api.baseURL = url
        api.apiKey = tmpKey
        info = "Updated."
    }
}
