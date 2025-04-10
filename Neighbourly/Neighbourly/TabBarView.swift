//
//  TabBarView.swift
//  Neighbourly
//
//  Created by Kevin Quah on 23/3/25.
//

import SwiftUI

struct TabBarView: View {
    var body: some View {
        TabView {
            HomeContentView() // Assuming this contains its own NavigationView if needed
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag("HomeTab")

            NewRequestView() // Assuming this contains its own NavigationView
                .tabItem {
                    Label("New Request", systemImage: "plus.circle.fill")
                }
                .tag("NewRequestTab")

            NavigationView { // Keep NavigationView for Chat list -> Detail
                ChatView()
            }
            .navigationViewStyle(.stack) // Use stack style if preferred
            .tabItem {
                Label("Chats", systemImage: "message.fill")
            }
            .tag("ChatTab")

            NavigationView { // Keep NavigationView for Profile -> Edit Profile
                // **** UPDATED: Pass nil for userId ****
                ProfileView(userId: nil) // Explicitly pass nil for logged-in user's profile
                // **** END UPDATE ****
            }
            .navigationViewStyle(.stack) // Use stack style if preferred
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag("ProfileTab")
        }
        .accentColor(.black) // Or your desired tint color
    }
}

#Preview {
    TabBarView()
}
