import SwiftUI
import QuickLook

struct TicketDetailView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.modelContext) private var context
    @ObservedObject var ticket: TicketEntity
    @State private var isPresentingEditor = false
    @State private var showingAttachment: TicketAttachmentEntity?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let details = ticket.details, !details.isEmpty {
                    Text(details)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !ticket.attachments.isEmpty {
                    attachmentsSection
                }
                activitySection
            }
            .padding()
        }
        .navigationTitle(ticket.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Edit") { isPresentingEditor = true }
                Button(action: { Task { await environment.syncEngine.sync(.tickets) } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            TicketEditorView(ticket: ticket)
                .environmentObject(environment)
        }
        .sheet(item: $showingAttachment) { attachment in
            AttachmentPreviewController(attachment: attachment)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("#\(ticket.number)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                StatusBadge(status: ticket.status)
                if let client = ticket.client {
                    Label(client.name, systemImage: "building.2")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.secondary)
                }
                if let assignee = ticket.assignee {
                    Label(assignee, systemImage: "person.fill")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.secondary)
                }
            }
            Text("Updated \(ticket.updatedAt.formatted(.relative(presentation: .named)))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Attachments")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                ForEach(ticket.attachments, id: \.id) { attachment in
                    AttachmentCard(attachment: attachment)
                        .onTapGesture { showingAttachment = attachment }
                }
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity")
                .font(.headline)
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Created", systemImage: "calendar")
                        Spacer()
                        Text(ticket.createdAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    HStack {
                        Label("Last Updated", systemImage: "clock")
                        Spacer()
                        Text(ticket.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
        }
    }
}

private struct StatusBadge: View {
    let status: TicketDTO.Status

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.badgeColor.opacity(0.2))
            .clipShape(Capsule())
            .foregroundStyle(status.badgeColor)
    }
}

private struct AttachmentCard: View {
    let attachment: TicketAttachmentEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Color.accentColor.gradient)
                .frame(height: 80)
                .overlay(alignment: .bottomLeading) {
                    Text(attachment.contentType)
                        .font(.caption2)
                        .padding(4)
                        .background(Color.black.opacity(0.5))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .padding(6)
                }
            Text(attachment.fileName)
                .font(.footnote)
                .lineLimit(2)
            Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.size), countStyle: .file))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct AttachmentPreviewController: UIViewControllerRepresentable {
    let attachment: TicketAttachmentEntity

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        controller.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(attachment: attachment)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let attachment: TicketAttachmentEntity

        init(attachment: TicketAttachmentEntity) {
            self.attachment = attachment
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            attachment.downloadURL as NSURL
        }
    }
}
