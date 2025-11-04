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
        tabAppearance.configureWithDefaultBackground()
        // Use a system material for adaptive light/dark appearance
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        tabAppearance.backgroundColor = nil
        tabAppearance.shadowColor = nil

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        // Use dynamic color for unselected items so it adapts in dark mode
        UITabBar.appearance().unselectedItemTintColor = UIColor.secondaryLabel

        // Navigation bar: adaptive material background for light/dark
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        navAppearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        navAppearance.backgroundColor = nil
        navAppearance.shadowColor = nil
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(api)
        }
    }
}
