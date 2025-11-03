import SwiftUI
import SwiftData

struct TicketEditorView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ClientEntity.name) private var clients: [ClientEntity]

    private let ticket: TicketEntity?
    @State private var draft: DraftTicket
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(ticket: TicketEntity?) {
        self.ticket = ticket
        if let ticket {
            _draft = State(initialValue: DraftTicket(from: ticket))
        } else {
            _draft = State(initialValue: DraftTicket())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $draft.title)
                    Picker("Status", selection: $draft.status) {
                        ForEach(TicketDTO.Status.allCases, id: \.self) { status in
                            Text(status.rawValue.capitalized).tag(status)
                        }
                    }
                    if !clients.isEmpty {
                        Picker("Client", selection: $draft.clientId) {
                            Text("Unassigned").tag(UUID?.none)
                            ForEach(clients, id: \.id) { client in
                                Text(client.name).tag(UUID?.some(client.id))
                            }
                        }
                    }
                    TextField("Assignee", text: $draft.assignee)
                }

                Section("Description") {
                    TextEditor(text: Binding($draft.description, default: ""))
                        .frame(height: 180)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle(ticket == nil ? "New Ticket" : "Edit Ticket")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!draft.isValid || isSaving)
                }
            }
        }
    }

    private func save() {
        Task {
            guard let clientId = draft.clientId ?? ticket?.client?.id else {
                errorMessage = "Please select a client"
                return
            }
            isSaving = true
            errorMessage = nil
            let request = TicketPayload(title: draft.title,
                                        description: draft.description,
                                        status: draft.status,
                                        clientId: clientId,
                                        assignee: draft.assignee.isEmpty ? nil : draft.assignee)
            do {
                let path: String
                let method: HTTPMethod
                if let ticket {
                    path = "/api/v1/tickets/\(ticket.id.uuidString)"
                    method = .patch
                } else {
                    path = "/api/v1/tickets"
                    method = .post
                }
                let endpoint = Endpoint<TicketDTO>(path: path,
                                                   method: method,
                                                   body: try Endpoint.jsonBody(request))
                let response = try await environment.apiClient.send(endpoint)
                if let dto = response.value {
                    try ModelMapper.upsert(ticket: dto, in: context)
                    try context.save()
                    try? await environment.syncEngine.sync(.tickets)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

private struct DraftTicket {
    var title: String = ""
    var status: TicketDTO.Status = .open
    var clientId: UUID?
    var assignee: String = ""
    var description: String?

    init() {}

    init(from ticket: TicketEntity) {
        self.title = ticket.title
        self.status = ticket.status
        self.clientId = ticket.client?.id
        self.assignee = ticket.assignee ?? ""
        self.description = ticket.details
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct TicketPayload: Codable {
    var title: String
    var description: String?
    var status: TicketDTO.Status
    var clientId: UUID
    var assignee: String?

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case status
        case clientId = "client_id"
        case assignee
    }
}

private extension Binding where Value == String {
    init(_ source: Binding<String?>, default defaultValue: String) {
        self.init(get: { source.wrappedValue ?? defaultValue }, set: { source.wrappedValue = $0 })
    }
}
