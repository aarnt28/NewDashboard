//
//  OverviewView.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//

import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.openURL) private var openURL

    @State private var totalTickets: Int = 0
    @State private var openTickets: Int = 0
    @State private var hardwareCount: Int = 0
    @State private var clientCount: Int = 0

    @State private var loading = false
    @State private var error: String?

    private var completionPercent: Int {
        guard totalTickets > 0 else { return 0 }
        let closed = totalTickets - openTickets
        return Int((Double(closed) / Double(totalTickets) * 100.0).rounded())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Button {
                        openURL(api.baseURL)
                    } label: {
                        Label("Open Web App", systemImage: "safari")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(VIPProminentButtonStyle())
                    .padding(.top, 6)

                    VStack(spacing: 18) {
                        StatCard(
                            title: "Tickets",
                            bigNumberLeft: openTickets,
                            bigNumberRight: totalTickets,
                            subtitleLeft: "Open",
                            subtitleRight: "Completion: \(completionPercent)%"
                        )

                        StatCard(
                            title: "Hardware Inventory",
                            bigNumberLeft: hardwareCount,
                            bigNumberRight: nil,
                            subtitleLeft: "Tracked assets",
                            subtitleRight: nil
                        )

                        StatCard(
                            title: "Client Roster",
                            bigNumberLeft: clientCount,
                            bigNumberRight: nil,
                            subtitleLeft: "Active relationships",
                            subtitleRight: nil
                        )
                    }

                    if let e = error {
                        Text(e)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(loading)
                }
            }
            .overlay {
                if loading { ProgressView() }
            }
            .task { await load() }
            .refreshable { await load() }
        }
        .vipScreenBackground()
    }

    @MainActor
    private func load() async {
        loading = true; defer { loading = false }
        error = nil
        do {
            async let ticketsTask = api.listTickets()
            async let hardwareTask = api.listHardware(limit: 1, offset: 0)     // we only need the count/total
            async let clientsTask = api.fetchClientsFlat()

            let (tickets, hardware, clients) = try await (ticketsTask, hardwareTask, clientsTask)

            totalTickets = tickets.count
            openTickets = tickets.filter { !$0.completed }.count

            // HardwareResult exposes .total, but fall back to count when nil
            hardwareCount = hardware.total ?? hardware.items.count

            clientCount = clients.count
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct StatCard: View {
    let title: String
    let bigNumberLeft: Int
    let bigNumberRight: Int?
    let subtitleLeft: String
    let subtitleRight: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.caption)
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.75))

            HStack(alignment: .firstTextBaseline) {
                Text("\(bigNumberLeft)")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                if let right = bigNumberRight {
                    Text("/\(right)")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()
            }

            HStack {
                Text(subtitleLeft)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                if let r = subtitleRight {
                    Text(r)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(VIPTheme.cardGradient)
        )
        .shadow(color: Color.vipBlue.opacity(0.18), radius: 18, x: 0, y: 14)
    }
}
