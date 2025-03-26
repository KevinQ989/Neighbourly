//
//  ChatView.swift
//  Neighbourly
//
//  Created by Esther Ker on 21/3/25.
//

import SwiftUI
import Supabase

enum ChatFilter {
    case all, requests, offers
}

struct ChatView: View {
    @State private var chats: [Chat] = []
    @State private var selectedTab: ChatFilter = .all

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

                // Filter buttons
                HStack {
                    FilterButton(title: "All", isSelected: selectedTab == .all) { selectedTab = .all }
                    FilterButton(title: "Your Requests", isSelected: selectedTab == .requests) { selectedTab = .requests }
                    FilterButton(title: "Your Offers", isSelected: selectedTab == .offers) { selectedTab = .offers }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Chat List
                List(filteredChats) { chat in
                    ChatRow(chat: chat)
                }
                .listStyle(PlainListStyle())
            }
            .navigationBarHidden(true)
            .onAppear {
                fetchChats()
            }
        }
    }

    var filteredChats: [Chat] {
        switch selectedTab {
        case .all:
            return chats
        case .requests:
            return chats.filter { $0.isRequest }
        case .offers:
            return chats.filter { !$0.isRequest }
        }
    }

    func fetchChats() {
        Task {
            do {
                let user = try await supabase.auth.session.user
                let fetchedChats: [Chat] = try await supabase
                    .from("chats")
                    .select()
                    .or("user1_id.eq.\(user.id), user2_id.eq.\(user.id)")
                    .execute()
                    .value
                
                var processedChats: [Chat] = []
                try await withThrowingTaskGroup(of: Chat?.self) { group in
                    for chat in fetchedChats {
                        group.addTask {
                            await processChat(chat)
                        }
                    }
                    
                    for try await processedChat in group {
                        if let chat = processedChat {
                            processedChats.append(chat)
                        }
                    }
                }
                
                chats = processedChats
            } catch {
                print("Error fetching chats: \(error)")
            }
        }
    }


}

func processChat(_ chat: Chat) async -> Chat? {
    do {
        // Example: Fetch the latest message for the chat
        let lastMessage: [Message] = try await supabase
            .from("messages")
            .select()
            .eq("chat_id", value: chat.id.uuidString)
            .order("timestamp", ascending: false)
            .limit(1)
            .execute()
            .value
        
        var updatedChat = chat
                if let last = lastMessage.first {
                    updatedChat.lastMessage = last.message
                    updatedChat.isUnread = !last.is_read
                }
                return updatedChat
    } catch {
        print("Error processing chat \(chat.id): \(error)")
        return nil
    }
}


// MARK: - Chat Model
struct Chat: Identifiable, Codable {
    let id: UUID
    let request_id: UUID
    let user1_id: UUID
    let user2_id: UUID
    var lastMessage: String = "No messages yet"
    var isUnread: Bool = false
    var isRequest: Bool = false  // True if the chat is about user's request

    var imageName: String { "profile_placeholder" } // Replace with profile picture logic
    var requestImage: String { "request_placeholder" } // Replace with request image logic
}

// MARK: - Message Model
struct Message: Identifiable, Codable {
    let id: UUID
    let chat_id: UUID
    let sender_id: UUID
    let message: String
    let timestamp: String
    let is_read: Bool
}

// MARK: - ChatRow (Updated)
struct ChatRow: View {
    let chat: Chat
    
    var body: some View {
        HStack {
            // Profile picture
            Image(chat.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            
            VStack(alignment: .leading) {
                HStack {
                    Text("Chat \(chat.id.uuidString.prefix(6))") // Placeholder for actual username
                        .font(.headline)
                    Text("11m") // Placeholder for timeAgo
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Text(chat.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .bold(chat.isUnread)
            }
            Spacer()
            
            if chat.isUnread {
                Image(systemName: "circle.fill")
                    .foregroundColor(.red)
            }

            // Request Image
            Image(chat.requestImage)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Filter Button
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

#Preview {
    ChatView()
}

