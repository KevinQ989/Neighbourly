//
//  NeighbourlyApp.swift
//  Neighbourly
//
//  Created by Yap Ze Kai on 20/3/25.
//

import SwiftUI

@main
struct NeighbourlyApp : App {
    
    // --- ADD THIS INIT METHOD ---
    init() {
        // Configure Tab Bar Appearance
        let tabBarAppearance = UITabBarAppearance()
        // Apply a standard opaque background
        tabBarAppearance.configureWithOpaqueBackground()

        // Apply the appearance to the standard tab bar
        UITabBar.appearance().standardAppearance = tabBarAppearance
        // Apply to scrolling edge appearance as well if needed for consistency
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
    // --- END INIT METHOD ---

    var body: some Scene {
        WindowGroup {
            AppView()
        }
    }
}
