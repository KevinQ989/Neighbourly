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
        // Use a Group to help compiler with conditional content
        Group {
            if isLoadingMessages && messages.isEmpty {
                // Centered Loading Indicator
                VStack { Spacer(); ProgressView("Loading Messages..."); Spacer() }
                    .frame(height: 200) // Give it some height
            } else if let errorMessage {
                // Centered Error Message
                VStack {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange).font(.largeTitle).padding(.bottom, 5)
                    Text("Error Loading Messages").font(.headline)
                    Text(errorMessage).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                    Button("Retry") { Task { await fetchMessages() } }.padding(.top)
                    Spacer()
                }
                .padding()
                .frame(height: 200)
            } else if messages.isEmpty {
                 // Centered Empty State Message
                 VStack {
                     Spacer()
                     Text("No messages yet. Start the conversation!")
                         .foregroundColor(.secondary)
                     Spacer()
                 }
                 .frame(height: 200) // Give it some height
            } else {
                // Message Bubbles
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                // Pass timestamp formatter
                                MessageView(message: message, isCurrentUser: message.senderId == currentUserId, formatter: messageTimestampFormatter)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
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

} // Brace 1 Close

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
