//
//  RootView.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//


import SwiftUI

struct RootView: View {
    @State private var selectedTab: AppTab = .overview

    var body: some View {
        ZStack {
            VIPTheme.backgroundGradient
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                OverviewView(selectTab: { selectedTab = $0 })
                    .tabItem { Label("Overview", systemImage: "rectangle.grid.3x3") }
                    .tag(AppTab.overview)

                ActiveView()
                    .tabItem { Label("Active", systemImage: "bolt.fill") }
                    .tag(AppTab.active)

                TicketsScreen()
                    .tabItem { Label("Tickets", systemImage: "doc.plaintext") }
                    .tag(AppTab.tickets)

                HardwareView()
                    .tabItem { Label("Hardware", systemImage: "shippingbox") }
                    .tag(AppTab.hardware)

                InventoryView()
                    .tabItem { Label("Inventory", systemImage: "list.bullet.clipboard.fill") }
                    .tag(AppTab.inventory)

                ClientsView()
                    .tabItem { Label("Clients", systemImage: "person.3") }
                    .tag(AppTab.clients)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(AppTab.settings)
            }
            .tint(.vipBlue)
        }
    }
}
