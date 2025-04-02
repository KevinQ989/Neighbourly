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
            HomeContentView()
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag("HomeTab")
            
            NewRequestView()
                .tabItem {
                    Label("New Request", systemImage: "plus.circle.fill")
                }
                .tag("NewRequestTab")
            
            NavigationView {
                ChatView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Chats", systemImage: "message.fill")
            }
            .tag("ChatTab")
            
            NavigationView {
                ProfileView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag("ProfileTab")
        }
        .accentColor(.black)
    }
}

#Preview {
    TabBarView()
}
