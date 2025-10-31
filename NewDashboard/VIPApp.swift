//
//  VIPApp.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//


import SwiftUI

@main
struct VIPApp: App {
    @StateObject private var api = APIClient()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(api)
        }
    }
}

