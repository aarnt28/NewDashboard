//
//  TicketsScreen.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//

import SwiftUI

struct TicketsScreen: View {
    @EnvironmentObject var api: APIClient

    @State private var tickets: [Ticket] = []
    @State private var error: String?
    @State private var loading = false
    @State private var showDeleteBanner = false
    @State private var deleteBannerText = ""
    
    @AppStorage("TicketsScreen.showCompleted") private var
        showCompleted: Bool = true
    
    private var filteredTickets: [Ticket] {
        tickets.filter { showCompleted || !$0.completed }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                List(filteredTickets, id: \.id) { t in
                    NavigationLink {
                        TicketDetailView(
                            ticket: t,
                            onUpdate: { (updated: Ticket) in
                                replaceTicket(updated)
                            },
                            onDelete: {
                                deleteTicket(t)
                            }
                        )
                    } label: {
                        TicketRow(ticket: t)
                    }
                    .listRowSeparator(.hidden)
                    //.listRowBackground(.adaptiveRow)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.white.opacity(0.8))
                        .shadow(color: Color.vipBlue.opacity(0.1), radius: 18, x: 0, y: 12)
                )
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .navigationTitle("Recent Tickets")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Toggle(isOn: $showCompleted) {
                            Label("Show Done", systemImage: showCompleted ? "checkmark.circle.fill" : "circle")
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .overlay {
                if loading && tickets.isEmpty { ProgressView() }
                if let e = error { Text(e).foregroundStyle(.red).padding() }
            }
            .overlay(alignment: .top) {
                if showDeleteBanner {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                        Text(deleteBannerText.isEmpty ? "Ticket deleted" : deleteBannerText)
                            .foregroundStyle(.white)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.8))
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .task { await reload() }
            .refreshable { await reload() }
        }
        .vipScreenBackground()
    }

    @MainActor
    private func reload() async {
        loading = true; defer { loading = false }
        do {
            tickets = try await api.listTickets()
            error = nil
        } catch let err {
            error = err.localizedDescription
        }
    }

    private func replaceTicket(_ updated: Ticket) {
        if let idx = tickets.firstIndex(where: { $0.id == updated.id }) {
            tickets[idx] = updated
        }
    }

    private func deleteTicket(_ t: Ticket) {
        Task {
            do {
                try await api.deleteTicket(id: t.id)
                await MainActor.run { tickets.removeAll { $0.id == t.id } }
                // Refresh the full list to ensure consistency
                await reload()
                // Show a confirmation banner
                await MainActor.run {
                    deleteBannerText = "Deleted ticket #\(t.id)"
                    withAnimation(.spring()) { showDeleteBanner = true }
                }
                // Auto-dismiss after 2 seconds
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    withAnimation { showDeleteBanner = false }
                }
            } catch {
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }
}

