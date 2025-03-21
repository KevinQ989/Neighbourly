//
//  ChatView.swift
//  Neighbourly
//
//  Created by Esther Ker on 21/3/25.
//

import SwiftUI

struct ChatView: View {
    @State private var selectedTab: ChatFilter = .all
    @State private var selectedChatId: Int? = nil
    
    @State private var chats = [
        Chat(id: 1, userName: "darentanrw", lastMessage: "Thanks so much!", timeAgo: "11m", imageName: "profile1", requestImage: "request1", isUnread: true, category: .offers),
        Chat(id: 2, userName: "zekaistic", lastMessage: "I can assist you!", timeAgo: "1d", imageName: "profile2", requestImage: "request2", isUnread: true, category: .requests),
        Chat(id: 3, userName: "kevq_", lastMessage: "Thank you :)", timeAgo: "1d", imageName: "profile3", requestImage: "request3", isUnread: false, category: .offers),
        Chat(id: 4, userName: "estherkyx_", lastMessage: "No problem!", timeAgo: "2d", imageName: "profile4", requestImage: "request4", isUnread: false, category: .requests),
        Chat(id: 5, userName: "ngjunying", lastMessage: "Does 5pm work for you?", timeAgo: "2d", imageName: "profile5", requestImage: "request5", isUnread: false, category: .offers),
        Chat(id: 6, userName: "mistermarcel", lastMessage: "Anytime!", timeAgo: "4d", imageName: "profile6", requestImage: "request6", isUnread: false, category: .requests)
    ]
    
    var filteredChats: [Chat] {
        switch selectedTab {
        case .all:
            return chats
        case .requests:
            return chats.filter { $0.category == .requests }
        case .offers:
            return chats.filter { $0.category == .offers }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                HStack {
                    Text("Chats")
                        .font(.title2)
                        .bold()
                    Spacer()
                }
                .padding(.horizontal)
                
                HStack {
                    FilterButton(title: "All", isSelected: selectedTab == .all) {
                        selectedTab = .all
                    }
                    FilterButton(title: "Your Requests", isSelected: selectedTab == .requests) {
                        selectedTab = .requests
                    }
                    FilterButton(title: "Your Offers", isSelected: selectedTab == .offers) {
                        selectedTab = .offers
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                List(filteredChats) { chat in
                    ChatRow(chat: chat, selectedChatId: $selectedChatId)
                }
                .listStyle(PlainListStyle())
                
                StatusBar()
            }
            .navigationBarHidden(true)
        }
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.black : Color.white)
                .foregroundColor(isSelected ? .white : .black)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
        }
    }
}

struct ChatRow: View {
    let chat: Chat
    @Binding var selectedChatId: Int?
    
    var body: some View {
        HStack {
            Image(chat.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            
            VStack(alignment: .leading) {
                HStack {
                    Text(chat.userName)
                        .font(.headline)
                    Text(chat.timeAgo)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Text(chat.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            
            Image(chat.requestImage)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 8)
    }
}

struct Chat: Identifiable {
    let id: Int
    let userName: String
    let lastMessage: String
    let timeAgo: String
    let imageName: String
    let requestImage: String
    let isUnread: Bool
    let category: ChatFilter
}

enum ChatFilter {
    case all, requests, offers
}

struct StatusBar: View {
    var body: some View {
        HStack {
            ForEach(["house.fill", "plus.circle.fill", "message.fill", "person.fill"], id: \ .self) { icon in
                Spacer()
                Button(action: {
                    // Handle tab selection
                }) {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(icon == "message.fill" ? .black : .gray)
                }
                Spacer()
            }
        }
        .padding(.vertical, 10)
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .top
        )
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
    }
}
