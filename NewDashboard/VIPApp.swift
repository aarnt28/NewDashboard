//
//  VIPApp.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//


import SwiftUI
import UIKit

@main
struct VIPApp: App {
    @StateObject private var api = APIClient()

    init() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Color.white.opacity(0.92))
        tabAppearance.shadowImage = UIImage()
        tabAppearance.shadowColor = .clear

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().unselectedItemTintColor = UIColor(Color.vipBlue.opacity(0.6))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(api)
        }
    }
}

