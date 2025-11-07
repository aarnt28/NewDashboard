//
//  TicketRow.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//


import SwiftUI

struct TicketRow: View {
    let ticket: Ticket

    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize

    // Compact = iPhone portrait; keep it tight.
    private var isCompactPhone: Bool {
        hSize == .compact && vSize == .regular
    }

    // Show “Running” ONLY for .time entries with no end time.
    private var isRunning: Bool {
        guard ticket.entry_type == .time else { return false }
        return ticket.end_iso == nil
    }

    private var statusText: String {
        ticket.completed ? "Done" : (isRunning ? "Running" : "Stopped")
    }

    private var startDate: Date? {
        ISO8601DateTransformer.parse(ticket.start_iso)
    }

    private var formattedDate: String {
        if let d = startDate {
            return d.formatted(date: .abbreviated, time: .shortened)
        }
        return ticket.created_at ?? ""
    }

    var body: some View {
        Group {
            if isCompactPhone {
                compactBody
            } else {
                fullBody
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
        )
    }

    // MARK: Compact layout (iPhone portrait) — only date + Done/Not Done
    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(ticket.client ?? ticket.client_key)
                    .font(.headline)
                    .foregroundStyle(Color.vipBlue)
                    .lineLimit(1)
                Spacer()
                VIPGradientPill(text: ticket.entry_type.displayName.uppercased())
            }

            if let desc = ticket.note, !desc.isEmpty {
                Text(desc)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Image(systemName: "calendar")
                Text(formattedDate)
                Spacer()
                if ticket.completed {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.vipGreen)
                } else {
                    Label("Not Done", systemImage: "circle")
                        .foregroundStyle(Color.vipBlue)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: Full layout (iPad / iPhone landscape) — richer quick stats
    private var fullBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(ticket.client ?? ticket.client_key)
                    .font(.headline)
                    .foregroundStyle(Color.vipBlue)
                    .lineLimit(1)
                Spacer()
                VIPGradientPill(text: ticket.entry_type.displayName.uppercased())
            }

            if let desc = ticket.note, !desc.isEmpty {
                Text(desc)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }

            // Status line
            HStack(spacing: 16) {
                Label(statusText, systemImage: isRunning ? "play.circle" : "pause.circle")
                if let mins = ticket.elapsed_minutes { Label("\(mins) min", systemImage: "clock") }
                if let inv = ticket.invoiced_total, !inv.isEmpty { Label(inv, systemImage: "dollarsign") }
                if let start = startDate { Label(start.formatted(date: .omitted, time: .shortened), systemImage: "calendar") }
                Spacer()
                if ticket.completed {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

