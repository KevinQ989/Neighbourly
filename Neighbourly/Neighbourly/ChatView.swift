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
    let currentUserId: UUID?

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
        HStack(spacing: 12) {
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

            // --- ADD Unread Indicator Overlay ---
            .overlay(alignment: .topTrailing) {
                if chat.isUnread {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5)) // Optional white border
                        .offset(x: 3, y: -3) // Adjust position
                }
            }
            // --- END Unread Indicator ---

            // --- End AsyncImage ---

            VStack(alignment: .leading, spacing: 2) { // Adjust spacing
                HStack {
                    Text(chat.otherParticipant.fullName ?? chat.otherParticipant.username ?? "Unknown User")
                        .font(.headline)
                    Spacer()
                    Text(formatTimestamp(chat.lastMessageTimestamp))
                        .font(.caption) // Make timestamp smaller
                        .foregroundColor(.gray)
                        .fontWeight(chat.isUnread ? .semibold : .regular)
                }
                // Add Request Title if available
                if let requestTitle = chat.requestTitle {
                    Text("Re: \(requestTitle)") // Prefix with "Re:"
                        .font(.caption) // Smaller font for request title
                        .foregroundColor(.blue) // Use a distinct color
                        .lineLimit(1)
                }
                // --- MODIFY Last Message Content ---
                HStack(spacing: 4) { // Use HStack for "You:" prefix
                    // Add "You:" prefix if current user sent the last message
                    if chat.lastMessageSenderId == currentUserId {
                        Text("You:")
                            .font(.subheadline)
                            .foregroundColor(.gray) // Match color
                            .fontWeight(.medium) // Make it slightly bolder
                    }
                    Text(chat.lastMessageContent ?? (chat.requestTitle == nil ? "No messages yet" : "Chat started"))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .fontWeight(chat.isUnread ? .medium : .regular)
                // --- END MODIFY Last Message ---
                Spacer()

                // --- ADD Request Image (Conditional) ---
                // Only show if requestImageUrl exists and is not empty
                if let imageUrl = chat.requestImageUrl, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .empty, .failure:
                            EmptyView() // Don't show placeholder if image fails/missing
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 45, height: 45) // Adjust size as needed
                    .clipped()
                    .cornerRadius(6)
                }
                // --- END ADD Request Image ---
            }
            .padding(.vertical, 8)
        }
    }
}


struct ChatView: View {
    @Environment(\.isAuthenticatedValue) private var isViewAuthenticated

    // State
    @State private var selectedTab: ChatFilter = .all
    @State private var chats: [Chat] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentUserId: UUID?

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

    var body: some View {
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
                            ChatRow(chat: chat, currentUserId: currentUserId) // Your existing ChatRow view
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
            await fetchCurrentUserId()
            await fetchChats()
        }
    } // End body

    // --- fetchCurrentUserId (Unchanged) ---
    @MainActor
    func fetchCurrentUserId() async {
        guard isViewAuthenticated else { return }
        guard currentUserId == nil else { return } // Fetch only once
        do {
            currentUserId = try await supabase.auth.session.user.id
        } catch {
            print("❌ ChatView: Error fetching current user ID: \(error)")
            errorMessage = "Could not identify current user." // Show error
        }
    }
    // --- END fetchCurrentUserId ---

    // --- Updated fetchChats Function (Outer wrapper unchanged) ---
    @MainActor
    func fetchChats() async {
        guard isViewAuthenticated else {
            print("❌ ChatView fetchChats: View not authenticated (environment). Skipping fetch.")
            self.errorMessage = "Please log in to view chats."
            self.isLoading = false
            self.chats = []
            return
        }
        guard let currentUserId = self.currentUserId else {
            print("❌ ChatView fetchChats: Current user ID not available. Fetching...")
            await fetchCurrentUserId()
            if self.currentUserId == nil {
                self.errorMessage = "Could not verify user to fetch chats."
                return
            }
            guard let fetchedUserId = self.currentUserId else { return }
            await fetchChatsInternal(currentUserId: fetchedUserId)
            return
        }
        await fetchChatsInternal(currentUserId: currentUserId)
    }

    // **** THIS FUNCTION IS UPDATED ****
    // --- Internal fetch function requiring userId ---
    @MainActor
    private func fetchChatsInternal(currentUserId: UUID) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        print("ChatView fetchChatsInternal: Starting fetch...")

        do {
            // --- UPDATED DECODING STRUCT ---
            // Add the new timestamp fields here
            struct BasicChatInfoWithDetails: Decodable, Identifiable { // Renamed for clarity
                let id: Int
                let requestId: Int?
                let requesterId: UUID
                let helperId: UUID
                let createdAt: Date
                // --- ADDED Fields ---
                let offerMadeAt: Date?
                let offerAcceptedAt: Date?
                let helperReviewedAt: Date?
                let requesterReviewedAt: Date?
                // --- END ADDED ---
                // Nested struct to decode related request data
                struct RequestInfo: Decodable {
                    let title: String?
                    let imageUrl: String?
                    enum CodingKeys: String, CodingKey {
                        case title
                        case imageUrl = "image_url"
                    }
                }
                let requests: RequestInfo? // Use table name 'requests'

                enum CodingKeys: String, CodingKey {
                    case id
                    case requestId = "request_id"
                    case requesterId = "requester_id"
                    case helperId = "helper_id"
                    case createdAt = "created_at"
                    // --- ADDED Keys ---
                    case offerMadeAt = "offer_made_at"
                    case offerAcceptedAt = "offer_accepted_at"
                    case helperReviewedAt = "helper_reviewed_at"
                    case requesterReviewedAt = "requester_reviewed_at"
                    // --- END ADDED ---
                    case requests // Matches the related table name
                }
            }
            // --- END UPDATED DECODING STRUCT ---


            // --- UPDATED QUERY ---
            // Select chat columns AND specific columns from the related 'requests' table
            // AND the new state columns from the 'chats' table
            let query = supabase.from("chats")
                .select("""
                    id, request_id, requester_id, helper_id, created_at,
                    offer_made_at, offer_accepted_at, helper_reviewed_at, requester_reviewed_at,
                    requests(title, image_url)
                """) // <-- INCLUDE new columns
                .or("requester_id.eq.\(currentUserId),helper_id.eq.\(currentUserId)")
                .order("created_at", ascending: false) // Keep ordering if needed

            // Decode using the modified struct
            let basicChatsWithDetails: [BasicChatInfoWithDetails] = try await query.execute().value
            // --- END UPDATED QUERY ---


            // --- Guard clause and profile fetching remain the same ---
            guard !basicChatsWithDetails.isEmpty else {
                self.chats = []; isLoading = false; print("No chats found for user."); return
            }
            var otherUserIds = Set<UUID>()
            let chatIds = basicChatsWithDetails.map { $0.id }
            for basicChat in basicChatsWithDetails { otherUserIds.insert((basicChat.requesterId == currentUserId) ? basicChat.helperId : basicChat.requesterId) }
            let profiles: [Profile] = try await supabase.from("profiles").select("id, username, full_name, avatar_url").in("id", value: Array(otherUserIds)).execute().value
            let profilesById = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
            // --- End profile fetching ---


            // --- Latest message fetching remains the same ---
            struct LatestMessage: Decodable {
                let chatId: Int
                let content: String
                let createdAt: Date
                let senderId: UUID
                enum CodingKeys: String, CodingKey {
                    case chatId = "chat_id"
                    case content
                    case createdAt = "created_at"
                    case senderId = "sender_id"
                }
            }
            let allMessagesForChats: [LatestMessage] = try await supabase
                .from("messages")
                .select("chat_id, content, created_at, sender_id")
                .in("chat_id", value: chatIds)
                .order("created_at", ascending: false)
                .execute()
                .value
            var latestMessageByChatId: [Int: LatestMessage] = [:]
            for message in allMessagesForChats { if latestMessageByChatId[message.chatId] == nil { latestMessageByChatId[message.chatId] = message } }
            // --- End latest message fetching ---


            // --- Read status fetching remains the same ---
            struct ReadStatus: Decodable {
                let chatId: Int
                let lastReadAt: Date?
                enum CodingKeys: String, CodingKey {
                    case chatId = "chat_id"
                    case lastReadAt = "last_read_at"
                }
            }
            let readStatuses: [ReadStatus] = try await supabase
                .from("chat_read_status")
                .select("chat_id, last_read_at")
                .eq("user_id", value: currentUserId)
                .in("chat_id", value: chatIds)
                .execute()
                .value
            let lastReadAtByChatId = Dictionary(uniqueKeysWithValues: readStatuses.map { ($0.chatId, $0.lastReadAt) })
            // --- End read status fetching ---


            // --- UPDATED CHAT OBJECT CREATION ---
            // Combine results
            var populatedChats: [Chat] = []
            for basicChat in basicChatsWithDetails { // Use the new struct name
                let otherUserId = (basicChat.requesterId == currentUserId) ? basicChat.helperId : basicChat.requesterId
                guard let otherProfile = profilesById[otherUserId] else { continue } // Skip if profile missing
                let latestMsg = latestMessageByChatId[basicChat.id]
                let lastReadTimestamp = lastReadAtByChatId[basicChat.id] ?? nil

                // Calculate isUnread (remains the same)
                var unread = false
                if let lastMsgTimestamp = latestMsg?.createdAt, latestMsg?.senderId != currentUserId {
                    if let lastRead = lastReadTimestamp {
                        if lastMsgTimestamp > lastRead { unread = true }
                    } else {
                        unread = true
                    }
                }

                // Create the Chat object using the UPDATED initializer
                let chat = Chat(
                    id: basicChat.id,
                    requestId: basicChat.requestId,
                    otherParticipant: otherProfile,
                    createdAt: basicChat.createdAt,
                    lastMessageContent: latestMsg?.content,
                    lastMessageTimestamp: latestMsg?.createdAt,
                    requestTitle: basicChat.requests?.title,
                    requestImageUrl: basicChat.requests?.imageUrl,
                    lastMessageSenderId: latestMsg?.senderId,
                    isUnread: unread,
                    // --- THESE ARGUMENTS MUST BE PRESENT ---
                    requesterId: basicChat.requesterId, // Pass from fetched data
                    helperId: basicChat.helperId,       // Pass from fetched data
                    // --- Pass the other new fields too ---
                    offerMadeAt: basicChat.offerMadeAt,
                    offerAcceptedAt: basicChat.offerAcceptedAt,
                    helperReviewedAt: basicChat.helperReviewedAt,
                    requesterReviewedAt: basicChat.requesterReviewedAt
                )
                populatedChats.append(chat)
            }
            // --- END UPDATED CHAT OBJECT CREATION ---


            // Sort final list (remains the same)
            self.chats = populatedChats.sorted { ($0.lastMessageTimestamp ?? $0.createdAt) > ($1.lastMessageTimestamp ?? $1.createdAt) }
            print("Processed \(self.chats.count) chats with latest messages and states.")

        } catch { // Error handling remains the same
            print("❌ Error fetching chats: \(error)")
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    // **** END UPDATED fetchChatsInternal FUNCTION ****

} // End ChatView struct


// FilterButton struct (Keep as is)
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).padding(.vertical, 8).padding(.horizontal, 12).background(isSelected ? Color.black : Color.white).foregroundColor(isSelected ? .white : .black).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.5), lineWidth: 1))
        }
    }
}


// Preview Provider
#Preview {
    NavigationView {
         ChatView()
    }
}
