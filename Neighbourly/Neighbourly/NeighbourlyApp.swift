//
//  NeighbourlyApp.swift
//  Neighbourly
//
//  Created by Yap Ze Kai on 20/3/25.
//

import SwiftUI

//@main
//struct NeighbourlyApp: App {
//   let persistenceController = PersistenceController.shared
//   @AppStorage("isLoggedIn") private var isLoggedIn = false
//
//    var body: some Scene {
//        WindowGroup {
//            if isLoggedIn {
//                HomePageView()
//                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
//            } else {
//               ContentView(isLoggedIn: $isLoggedIn)
//                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
//            }
//        }
//    }
//}

@main
struct NeighbourlyApp : App {
    var body: some Scene {
        WindowGroup {
            AppView()
        }
    }
}
