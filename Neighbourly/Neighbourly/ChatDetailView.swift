// ChatDetailView.swift

import SwiftUI
import Supabase
import Combine // Import Combine

struct ChatDetailView: View { // Brace 1 Open
    // Input: The chat thread information
    let chat: Chat

    // State for messages, input field, etc.
    @State private var messages: [ChatMessage] = []
    @State private var newMessageText: String = ""
    @State private var isLoadingMessages = false
    @State private var isSendingMessage = false
    @State private var errorMessage: String?
    @State private var currentUserId: UUID?
    
    // --- ADD State for Associated Request ---
    @State private var associatedRequest: RequestData? = nil
    @State private var isLoadingRequest = false
    // --- END State ---

    // State for Realtime subscription
    @State private var channel: RealtimeChannel? = nil
    // Task handle for the subscription listener
    @State private var listenerTask: Task<Void, Never>? = nil

    // ScrollView reader to scroll to bottom
    @State private var scrollViewProxy: ScrollViewProxy? = nil

    // Standard JSON Decoder with Date Strategy
    private var jsonDecoder: JSONDecoder {
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
    }

    // Date Formatter for message timestamps
    private var messageTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none // No date part
        formatter.timeStyle = .short // e.g., 10:30 AM
        return formatter
    }()

    // ****** FIX: Add explicit internal initializer ******
    // This ensures the preview has access, even with private computed properties.
    internal init(chat: Chat) {
        self.chat = chat
    }
    // ****** END FIX ******

    var body: some View { // Brace 2 Open
        VStack(spacing: 0) { // Use 0 spacing
            // --- Message List ---
            messageListView // Extracted computed property
            // --- End Message List ---
        } // End Main VStack
        .safeAreaInset(edge: .bottom) { // Push input field above keyboard
            messageInputArea
        }
        .navigationTitle(chat.otherParticipant.fullName ?? chat.otherParticipant.username ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task { // Use .task for async setup and automatic cleanup
            await setupChat()
            await fetchAssociatedRequest()
            await markChatAsRead()
            // Explicit cleanup using the return closure from .task
            return {
                listenerTask?.cancel() // Cancel listener task
                Task { await unsubscribeFromMessages() } // Unsubscribe channel
            }()
        }
        .onAppear { // Fetch user ID immediately on appear
             Task { await fetchCurrentUserId() }
        }
    } // Brace 2 Close

    // Extracted Message List View to help compiler
    @ViewBuilder
    private var messageListView: some View {
        Group {
            if isLoadingMessages && messages.isEmpty {
                VStack { Spacer(); ProgressView("Loading Messages..."); Spacer() }.frame(maxHeight: .infinity) // Give it more space
            } else if let errorMessage {
                VStack { /* ... Error display ... */ }.padding().frame(maxHeight: .infinity)
            } else if messages.isEmpty {
                 VStack { Spacer(); Text("No messages yet. Start the conversation!").foregroundColor(.secondary); Spacer() }.frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                // --- ADD Request Context Display Logic ---
                                // Check if it's the first message AND there's an associated request
                                if message.id == messages.first?.id, let assocReq = associatedRequest {
                                    NavigationLink(destination: RequestDetailView(request: assocReq)) {
                                        RequestContextView(request: assocReq) // New subview for context
                                    }
                                    .padding(.vertical, 5) // Add some spacing
                                    .buttonStyle(.plain) // Make link look like content
                                }
                                // --- END Request Context Display Logic ---

                                // Display the actual message bubble
                                MessageView(
                                    message: message,
                                    isCurrentUser: message.senderId == currentUserId,
                                    formatter: messageTimestampFormatter
                                )
                                .id(message.id) // Keep ID for scrolling
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top) // Add padding at the top
                    }
                    .onAppear {
                        scrollViewProxy = proxy
                        if !messages.isEmpty { scrollToBottom(proxy: proxy, animated: false) }
                    }
                    .onChange(of: messages) { _ in scrollToBottom(proxy: proxy) }
                } // End ScrollViewReader
            }
        } // End Group
    }
    // --- END MODIFY messageListView ---

    // Extracted Message Input Area View
    private var messageInputArea: some View {
        HStack(alignment: .bottom) { // Align items to bottom
            TextEditor(text: $newMessageText)
                .frame(minHeight: 30, maxHeight: 100) // Set min/max height
                .padding(4) // Inner padding
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(UIColor.systemGray4))
                )

            Button {
                sendMessage() // Call send function
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30) // Fixed size for button
                    .foregroundColor(newMessageText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue) // Change color when disabled
            }
            .disabled(newMessageText.trimmingCharacters(in: .whitespaces).isEmpty || isSendingMessage) // Disable if empty or sending
        }
        .padding(.horizontal)
        .padding(.vertical, 8) // Add vertical padding
        .background(.thinMaterial) // Add a background material
    }

    // MARK: - Helper Functions

    // Combined setup function called from .task
    @MainActor
    func setupChat() async {
        if currentUserId == nil { await fetchCurrentUserId() }
        guard currentUserId != nil else { return }

        await fetchMessages()
        subscribeToMessages() // Non-async call to setup subscription
    }

    // Function to get current user ID
    @MainActor
    func fetchCurrentUserId() async {
        guard currentUserId == nil else { return } // Fetch only once
        do {
            currentUserId = try await supabase.auth.session.user.id
        } catch {
            print("❌ Error fetching current user ID: \(error)")
            errorMessage = "Could not identify current user."
        }
    }

    // Function to fetch initial messages
    @MainActor
    func fetchMessages() async {
        guard !isLoadingMessages else { return } // Prevent concurrent fetches
        isLoadingMessages = true
        errorMessage = nil // Clear previous errors on retry/fetch

        do {
            let fetchedMessages: [ChatMessage] = try await supabase
                .from("messages")
                .select() // Select columns matching ChatMessage
                .eq("chat_id", value: chat.id) // Filter by chat ID
                .order("created_at", ascending: true) // Oldest first
                .execute()
                .value // Use .value assuming execute returns decoded value

            self.messages = fetchedMessages
            print("Fetched \(fetchedMessages.count) messages for chat \(chat.id)")
            // Scroll after messages are set
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // Slight delay ensures layout is ready
                 scrollToBottom(proxy: scrollViewProxy, animated: false)
            }

        } catch {
            print("❌ Error fetching messages: \(error)")
            errorMessage = "Failed to load messages: \(error.localizedDescription)"
        }
        isLoadingMessages = false
    }

    // Updated sendMessage with Optimistic UI
    @MainActor
    func sendMessage() {
        guard let userId = currentUserId, !newMessageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard !isSendingMessage else { return } // Prevent double sends

        let textToSend = newMessageText.trimmingCharacters(in: .whitespaces)
        newMessageText = "" // Clear input field immediately

        // --- Optimistic UI Update ---
        let optimisticId = -Int.random(in: 1...1000000)
        let optimisticMessage = ChatMessage(
            id: optimisticId,
            chatId: chat.id,
            senderId: userId,
            content: textToSend,
            createdAt: Date() // Use current time locally
        )
        messages.append(optimisticMessage) // Add to list immediately
        scrollToBottom(proxy: scrollViewProxy) // Scroll to show it
        // --- End Optimistic UI ---

        isSendingMessage = true // Indicate sending state (can disable input)
        errorMessage = nil // Clear previous errors

        Task { // Perform Supabase operation in background task
            let params = NewMessageParams(chatId: chat.id, senderId: userId, content: textToSend)
            do {
                // Send to Supabase
                try await supabase.from("messages").insert(params, returning: .minimal).execute()
                print("✅ Message sent successfully.")
                // Realtime should eventually deliver the confirmed message.
            } catch {
                print("❌ Error sending message: \(error)")
                errorMessage = "Failed to send message." // Simple error message
                // --- Revert Optimistic Update on Failure ---
                messages.removeAll { $0.id == optimisticId }
                newMessageText = textToSend // Put text back for user to retry
                // --- End Revert ---
            }
            isSendingMessage = false // Reset sending state
        }
    }

    // Function to subscribe to new messages via Realtime
    @MainActor
    func subscribeToMessages() { // Made non-async
        guard self.channel == nil else { // Subscribe only once
            print("⚠️ Already subscribed or channel exists.")
            return
        }
        guard currentUserId != nil else {
            print("⚠️ Cannot subscribe: Current user ID not available.")
            return
        }

        let channelTopic = "public:messages:chat_id=eq.\(chat.id)"
        print("Subscribing to channel topic: \(channelTopic)")

        let newChannel = supabase.realtime.channel(channelTopic)

        // Define the callback closure (handler)
        let messageHandler = { (message: RealtimeMessage) in
            print("🟢 Realtime Change Received: \(message.payload)")
            let eventType = message.payload["type"] as? String
            guard eventType == "INSERT" else {
                 print("ℹ️ Realtime: Ignoring non-INSERT event (\(eventType ?? "unknown"))")
                 return
            }
            do {
                guard let recordPayload = message.payload["record"] as? [String: Any] else {
                    print("🔴 Realtime: 'record' not found in INSERT payload.")
                    return
                }
                let jsonData = try JSONSerialization.data(withJSONObject: recordPayload)
                let newMessage = try self.jsonDecoder.decode(ChatMessage.self, from: jsonData)
                print("🟢 Decoded new message: \(newMessage.content)")

                Task { @MainActor in
                    if !self.messages.contains(where: { $0.id == newMessage.id }) {
                        self.messages.append(newMessage)
                    } else {
                        print("ℹ️ Realtime: Received duplicate message ID \(newMessage.id). Ignoring.")
                    }
                }
            } catch {
                print("🔴 Realtime: Failed to decode new message payload. Error: \(error)")
            }
        }

        // Construct the ChannelFilter object
        let channelFilter = ChannelFilter(
            event: "INSERT",
            schema: "public",
            table: "messages",
            filter: "chat_id=eq.\(chat.id)"
        )

        // Subscribe using the .on() method with ChannelFilter and handler
        newChannel.on("INSERT", filter: channelFilter, handler: messageHandler)
        .subscribe { status, error in // Handle subscription status changes
            if let error = error {
                print("🔴 Realtime subscription error: \(error.localizedDescription)")
                // ****** FIX: Ensure state update is on MainActor ******
                Task { @MainActor in
                    self.errorMessage = "Realtime connection error."
                    self.channel = nil
                }
                // ****** END FIX ******
            } else {
                print("🟢 Realtime subscription status: \(status)")
                if status == .subscribed {
                    // ****** FIX: Ensure state update is on MainActor ******
                    Task { @MainActor in
                         self.channel = newChannel // Assign the channel here
                    }
                    // ****** END FIX ******
                }
            }
        }
    }


    // Function to unsubscribe from Realtime channel
    @MainActor
    func unsubscribeFromMessages() async {
        print("Attempting to unsubscribe...") // Add log
        guard let currentChannel = self.channel else {
             print("Unsubscribe skipped: Channel is nil.")
             return
        }
        print("Unsubscribing from channel: \(currentChannel.topic)")
        do {
            try await currentChannel.unsubscribe()
            self.channel = nil
            print("✅ Successfully unsubscribed.")
        } catch {
            print("🔴 Error unsubscribing from channel: \(error)")
            self.channel = nil // Clear local state even if unsubscribe fails
        }
    }

    // Function to scroll to the bottom of the message list
    private func scrollToBottom(proxy: ScrollViewProxy?, animated: Bool = true) {
        guard let proxy = proxy, let lastMessageId = messages.last?.id else { return }
        if animated {
            withAnimation(.spring()) {
                proxy.scrollTo(lastMessageId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastMessageId, anchor: .bottom)
        }
    }
    
    // --- ADD fetchAssociatedRequest function ---
    @MainActor
    func fetchAssociatedRequest() async {
        guard let reqId = chat.requestId else {
            print("Chat \(chat.id) is not associated with a specific request.")
            return // No request ID to fetch
        }
        guard associatedRequest == nil, !isLoadingRequest else { return } // Fetch only once

        isLoadingRequest = true
        print("Fetching associated request with ID: \(reqId)")
        do {
            let fetchedRequest: RequestData = try await supabase
                .from("requests")
                .select() // Select columns matching RequestData
                .eq("id", value: reqId)
                .single() // Expect exactly one request
                .execute()
                .value
            self.associatedRequest = fetchedRequest
            print("✅ Fetched associated request: \(fetchedRequest.title)")
        } catch {
            print("❌ Error fetching associated request \(reqId): \(error)")
            // Handle error appropriately (e.g., show a message)
            // For now, we just log it. The request context won't appear.
        }
        isLoadingRequest = false
    }
    // --- END fetchAssociatedRequest ---
    
    // --- ADD Function to update read status ---
    @MainActor
    func markChatAsRead() async {
        guard let userId = currentUserId else {
            print("⚠️ markChatAsRead: Cannot mark as read, user ID not available.")
            return
        }
        print("➡️ markChatAsRead: Updating last_read_at for chat \(chat.id), user \(userId)")
        do {
            // Upsert: Insert or update the read status for this user and chat
            // Sets last_read_at to the current time.
            struct ReadStatusParams: Encodable {
                let chat_id: Int
                let user_id: UUID
                let last_read_at: Date // Use current date
            }
            let params = ReadStatusParams(chat_id: chat.id, user_id: userId, last_read_at: Date())

            try await supabase
                .from("chat_read_status")
                .upsert(params, onConflict: "chat_id, user_id") // Specify conflict columns
                .execute()
            print("✅ markChatAsRead: Successfully updated read status.")
        } catch {
            print("❌ markChatAsRead: Error updating read status - \(error)")
            // Handle error - maybe retry later? For now, just log.
        }
    }
    // --- END Function ---

} // Brace 1 Close

// --- ADD THIS NEW SUBVIEW for displaying request context ---
struct RequestContextView: View {
    let request: RequestData

    var body: some View {
        HStack(spacing: 8) {
            // Request Image
            AsyncImage(url: URL(string: request.imageUrl ?? "")) { phase in
                 switch phase {
                 case .empty: ZStack { Rectangle().fill(Color.gray.opacity(0.1)); ProgressView() }
                 case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                 case .failure: ZStack { Rectangle().fill(Color.gray.opacity(0.1)); Image(systemName: "photo.fill").foregroundColor(.gray) }
                 @unknown default: EmptyView()
                 }
             }
             .frame(width: 40, height: 40).clipped().cornerRadius(5)

            // Request Title
            VStack(alignment: .leading) {
                 Text("Regarding Request:")
                     .font(.caption2)
                     .foregroundColor(.gray)
                 Text(request.title)
                     .font(.caption)
                     .fontWeight(.medium)
                     .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.gray) // Indicate tappable
        }
        .padding(8)
        .background(Color(UIColor.systemGray5)) // Subtle background
        .cornerRadius(8)
    }
}
// --- END RequestContextView ---

// MARK: - Message View Subview

struct MessageView: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    let formatter: DateFormatter // Pass formatter

    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer() // Push to right
                VStack(alignment: .trailing, spacing: 2) { // Align timestamp below bubble
                    Text(message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedCorner(radius: 12, corners: [.topLeft, .topRight, .bottomLeft])) // Chat bubble shape
                    // Show timestamp below bubble
                    Text(formatter.string(from: message.createdAt))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) { // Align timestamp below bubble
                    Text(message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.systemGray5))
                        .foregroundColor(Color(UIColor.label)) // Adapts to light/dark mode
                        .clipShape(RoundedCorner(radius: 12, corners: [.topLeft, .topRight, .bottomRight])) // Chat bubble shape
                    // Show timestamp below bubble
                    Text(formatter.string(from: message.createdAt))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer() // Push to left
            }
        }
    }
}

// Helper for specific corner rounding
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}


// MARK: - Preview Provider

#Preview {
    // Create sample data matching the Chat model for preview
    let sampleOtherProfile = Profile(id: UUID(), username: "previewUser", fullName: "Preview User", website: nil, avatarUrl: nil)
    let sampleChat = Chat(id: 99, requestId: 1, otherParticipant: sampleOtherProfile, createdAt: Date())

    // Embed in NavigationView for the preview to show title bar
    NavigationView {
        // Use the explicit initializer
        ChatDetailView(chat: sampleChat)
    }
}
