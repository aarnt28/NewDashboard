import SwiftUI

struct APIKeyEntryView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Paste your API Key")) {
                    TextEditor(text: $apiKey)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("Authenticate")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: submit) {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Continue")
                        }
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
        }
    }

    private func submit() {
        Task {
            isSubmitting = true
            errorMessage = nil
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            await environment.authenticationController.updateAPIKey(trimmed)
            do {
                try await environment.authenticationController.exchangeAPIKeyForJWT()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
