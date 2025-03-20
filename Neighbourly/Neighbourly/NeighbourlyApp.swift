//
//  NeighbourlyApp.swift
//  Neighbourly
//
//  Created by Yap Ze Kai on 20/3/25.
//

import SwiftUI

@main
struct NeighbourlyApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
