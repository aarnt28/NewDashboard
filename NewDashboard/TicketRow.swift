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
        if isCompactPhone {
            compactBody
        } else {
            fullBody
        }
    }

    // MARK: Compact layout (iPhone portrait) — only date + Done/Not Done
    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(ticket.client ?? ticket.client_key)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Pill(text: ticket.entry_type.displayName.uppercased())
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
                } else {
                    Label("Not Done", systemImage: "circle")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: Full layout (iPad / iPhone landscape) — richer quick stats
    private var fullBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(ticket.client ?? ticket.client_key)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Pill(text: ticket.entry_type.displayName.uppercased())
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
        .padding(.vertical, 8)
    }
}

// Small utility for the “TIME / HARDWARE / DEPLOYMENT” capsule
private struct Pill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
            )
    }
}
