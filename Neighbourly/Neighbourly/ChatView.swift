// ChatView.swift

import SwiftUI
import Supabase

// ChatFilter enum remains the same
enum ChatFilter {
    case all
}

// Updated ChatRow to use the new Chat model and display last message & avatar
struct ChatRow: View {
    let chat: Chat

    // Date formatter for relative time
    private static var relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    // Function to format timestamp relatively
    private func formatTimestamp(_ date: Date?) -> String {
        guard let date = date else { return "" }
        if Calendar.current.isDateInToday(date) || Calendar.current.isDateInYesterday(date) {
             return ChatRow.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
        } else {
             return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }

    var body: some View {
        HStack {
            // --- Use AsyncImage for Avatar ---
            AsyncImage(url: URL(string: chat.otherParticipant.avatarUrl ?? "")) { phase in
                switch phase {
                case .empty:
                    Image(systemName: "person.circle.fill")
                        .resizable().foregroundColor(.gray)
                        .overlay(ProgressView().scaleEffect(0.5))
                case .success(let image):
                    image.resizable()
                case .failure:
                    Image(systemName: "person.circle.fill")
                        .resizable().foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
            .scaledToFit() // Use fit for avatar
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            // --- End AsyncImage ---

            VStack(alignment: .leading) {
                HStack {
                    // Other participant's name
                    Text(chat.otherParticipant.fullName ?? chat.otherParticipant.username ?? "Unknown User")
                        .font(.headline)
                    Spacer()
                    // Display last message timestamp (relative)
                    Text(formatTimestamp(chat.lastMessageTimestamp))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                // Display last message content
                Text(chat.lastMessageContent ?? "No messages yet")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            Spacer()

        }
        .padding(.vertical, 8)
    }
}


struct ChatView: View { // Brace 1 Open
    @Environment(\.isAuthenticatedValue) private var isViewAuthenticated
    
    // State
    @State private var selectedTab: ChatFilter = .all
    @State private var chats: [Chat] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Filtered chats (simplified)
    var filteredChats: [Chat] {
        return chats
    }

    // Standard JSON Decoder
    private var jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) { return date }
            formatter.formatOptions = [.withInternetDateTime] // Fallback
            if let date = formatter.date(from: dateString) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        return decoder
    }()

    var body: some View { // Brace 2 Open
        VStack(spacing: 0) { // Use spacing 0

            // Filter Buttons (Commented out)
            /*
            HStack {
                FilterButton(title: "All", isSelected: selectedTab == .all) { selectedTab = .all }
                // FilterButton(title: "Your Requests", ...)
                // FilterButton(title: "Your Offers", ...)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemGroupedBackground))
            */

            // Handle Loading/Error/Empty States
            if isLoading {
                ProgressView("Loading Chats...")
                    .frame(maxHeight: .infinity)
            } else if let errorMessage {
                VStack {
                    Text("Error loading chats:")
                    Text(errorMessage).foregroundColor(.red).font(.caption)
                    Button("Retry") { Task { await fetchChats() } }
                        .padding(.top)
                }
                .frame(maxHeight: .infinity)
            } else if chats.isEmpty {
                Text("No chats yet.")
                    .foregroundColor(.gray)
                    .frame(maxHeight: .infinity)
            } else {
                // --- MODIFIED List of Chats ---
                List { // Use List directly
                    ForEach(chats) { chat in
                        // Wrap ChatRow in NavigationLink to ChatDetailView
                        NavigationLink(destination: ChatDetailView(chat: chat)) {
                             ChatRow(chat: chat) // Your existing ChatRow view
                        }
                    }
                } // End List
                .listStyle(PlainListStyle()) // Use plain style
                .refreshable { // Keep refreshable
                    await fetchChats()
                }
                // --- END MODIFIED List ---
            }

        } // End VStack
        .navigationTitle("Chats")
        .task { // Fetch chats when the view appears
            await fetchChats()
        }
    } // Brace 2 Close

    // --- Updated fetchChats Function ---
    @MainActor
    func fetchChats() async { // Brace 11 Open
        // --- MODIFY Start of function ---
        guard isViewAuthenticated else {
            print("❌ ChatView fetchChats: View not authenticated (environment). Skipping fetch.")
            self.errorMessage = "Please log in to view chats."
            self.isLoading = false
            self.chats = []
            return
        }
        // --- END MODIFICATION ---

        // Remove the explicit `try await supabase.auth.session` check here,
        // as we now rely on the environment value passed down from AppView.

        guard !isLoading else { /* ... */ return }

        isLoading = true
        errorMessage = nil
        print("ChatView fetchChats: Starting fetch...")

        do { // Brace 12 Open
            // 1. Get current user ID
            let currentUserId = try await supabase.auth.session.user.id

            // Query 1: Fetch basic chat info
            struct BasicChatInfo: Decodable, Identifiable {
                let id: Int; let requestId: Int?; let requesterId: UUID; let helperId: UUID; let createdAt: Date
                 enum CodingKeys: String, CodingKey { case id; case requestId = "request_id"; case requesterId = "requester_id"; case helperId = "helper_id"; case createdAt = "created_at" }
            }
            let basicChats: [BasicChatInfo] = try await supabase.from("chats").select("id, request_id, requester_id, helper_id, created_at").or("requester_id.eq.\(currentUserId),helper_id.eq.\(currentUserId)").order("created_at", ascending: false).execute().value

            guard !basicChats.isEmpty else {
                self.chats = []; isLoading = false; print("No chats found for user."); return
            }

            // 3. Prepare for fetching profiles and latest messages
            var otherUserIds = Set<UUID>()
            let chatIds = basicChats.map { $0.id }
            for basicChat in basicChats { otherUserIds.insert((basicChat.requesterId == currentUserId) ? basicChat.helperId : basicChat.requesterId) }

            // Query 2: Fetch profiles
            let profiles: [Profile] = try await supabase.from("profiles").select("id, username, full_name, avatar_url").in("id", value: Array(otherUserIds)).execute().value
            let profilesById = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

            // Query 3: Fetch latest messages
            struct LatestMessage: Decodable { let chatId: Int; let content: String; let createdAt: Date; enum CodingKeys: String, CodingKey { case chatId = "chat_id"; case content; case createdAt = "created_at" } }
            let allMessagesForChats: [LatestMessage] = try await supabase.from("messages").select("chat_id, content, created_at").in("chat_id", value: chatIds).order("created_at", ascending: false).execute().value

            // Process latest messages client-side
            var latestMessageByChatId: [Int: LatestMessage] = [:]
            for message in allMessagesForChats { if latestMessageByChatId[message.chatId] == nil { latestMessageByChatId[message.chatId] = message } }

            // 4. Combine results
            var populatedChats: [Chat] = []
            for basicChat in basicChats { // Brace 13 Open
                let otherUserId = (basicChat.requesterId == currentUserId) ? basicChat.helperId : basicChat.requesterId
                guard let otherProfile = profilesById[otherUserId] else {
                    print("⚠️ Profile not found for user \(otherUserId) in chat \(basicChat.id). Creating placeholder.")
                    let placeholderProfile = Profile(id: otherUserId, username: "Unknown", fullName: "Unknown User", website: nil, avatarUrl: nil)
                    let latestMsg = latestMessageByChatId[basicChat.id]
                    let chat = Chat(id: basicChat.id, requestId: basicChat.requestId, otherParticipant: placeholderProfile, createdAt: basicChat.createdAt, lastMessageContent: latestMsg?.content, lastMessageTimestamp: latestMsg?.createdAt)
                    populatedChats.append(chat)
                    continue
                }
                let latestMsg = latestMessageByChatId[basicChat.id]
                let chat = Chat(id: basicChat.id, requestId: basicChat.requestId, otherParticipant: otherProfile, createdAt: basicChat.createdAt, lastMessageContent: latestMsg?.content, lastMessageTimestamp: latestMsg?.createdAt)
                populatedChats.append(chat)
            } // Brace 13 Close

            // Sort final list
            self.chats = populatedChats.sorted { ($0.lastMessageTimestamp ?? $0.createdAt) > ($1.lastMessageTimestamp ?? $1.createdAt) }
            print("Processed \(self.chats.count) chats with latest messages.")

        } catch { // Brace 12 Close, Brace 16 Open
            print("❌ Error fetching chats: \(error)")
            self.errorMessage = error.localizedDescription
        } // Brace 16 Close
        isLoading = false
    } // Brace 11 Close

} // Brace 1 Close


// FilterButton struct (Keep as is)
struct FilterButton: View { // Brace 17 Open
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View { // Brace 18 Open
        Button(action: action) { // Brace 19 Open
            Text(title).padding(.vertical, 8).padding(.horizontal, 12).background(isSelected ? Color.black : Color.white).foregroundColor(isSelected ? .white : .black).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.5), lineWidth: 1))
        } // Brace 19 Close
    } // Brace 18 Close
} // Brace 17 Close


// Preview Provider
#Preview { // Brace 20 Open
    NavigationView { // Brace 21 Open
         ChatView()
    } // Brace 21 Close
} // Brace 20 Close
