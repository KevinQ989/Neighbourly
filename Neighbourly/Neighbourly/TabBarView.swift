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
                    Image(systemName: "house.fill")
                }
            
            NewRequestView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                }
            
            ChatView()
                .tabItem {
                    Image(systemName: "message.fill")
                }
            NavigationView{
                ProfileView()}
                .tabItem {
                    Image(systemName: "person.fill")
                }
        }
        .accentColor(.black)
    }
}

#Preview {
    TabBarView()
}
