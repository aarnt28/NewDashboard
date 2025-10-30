//
//  RootView.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//


import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("Overview", systemImage: "rectangle.grid.2x2") }

            ActiveView()
                .tabItem { Label("Active", systemImage: "bolt.fill") }

            TicketsScreen()                // or TicketsView if you renamed it
                .tabItem { Label("Tickets", systemImage: "doc.plaintext") }

            HardwareView()
                .tabItem { Label("Hardware", systemImage: "shippingbox") }

            ClientsView()
                .tabItem { Label("Clients", systemImage: "person.3") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
