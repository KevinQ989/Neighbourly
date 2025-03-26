// ChatDetailView.swift

import SwiftUI
import Supabase
import Realtime // <-- Explicitly import Realtime
import Combine

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
                Task { await unsubscribeFromMessages() }
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
                ProgressView("Loading Messages...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Center loading
            } else if let errorMessage {
                 VStack {
                     Text("Error:")
                     Text(errorMessage).foregroundColor(.red).font(.caption)
                     Button("Retry Fetch") { Task { await fetchMessages() } }
                         .padding(.top)
                 }
                 .padding()
                 .frame(maxWidth: .infinity, maxHeight: .infinity) // Center error
            } else {
                // Only show ScrollViewReader if there are messages or no error/loading
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageView(message: message, isCurrentUser: message.senderId == currentUserId)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .onAppear {
                        scrollViewProxy = proxy
                        if !messages.isEmpty {
                            scrollToBottom(proxy: proxy, animated: false)
                        }
                    }
                    .onChange(of: messages) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                } // End ScrollViewReader
            }
        } // End Group
    }

    // Extracted Message Input Area View
    private var messageInputArea: some View {
        HStack(alignment: .bottom) {
            TextEditor(text: $newMessageText)
                .frame(minHeight: 30, maxHeight: 100)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(UIColor.systemGray4))
                )

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(newMessageText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
            }
            .disabled(newMessageText.trimmingCharacters(in: .whitespaces).isEmpty || isSendingMessage)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }

    // MARK: - Helper Functions

    @MainActor
    func setupChat() async {
        if currentUserId == nil { await fetchCurrentUserId() }
        guard currentUserId != nil else { return }
        await fetchMessages()
        subscribeToMessages() // Non-async
    }

    @MainActor
    func fetchCurrentUserId() async {
        guard currentUserId == nil else { return }
        do {
            currentUserId = try await supabase.auth.session.user.id
        } catch {
            print("❌ Error fetching current user ID: \(error)")
            errorMessage = "Could not identify current user."
        }
    }

    @MainActor
    func fetchMessages() async {
        guard !isLoadingMessages else { return }
        isLoadingMessages = true
        errorMessage = nil

        do {
            let fetchedMessages: [ChatMessage] = try await supabase
                .from("messages")
                .select()
                .eq("chat_id", value: chat.id)
                .order("created_at", ascending: true)
                .execute()
                .value

            self.messages = fetchedMessages
            print("Fetched \(fetchedMessages.count) messages for chat \(chat.id)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                 scrollToBottom(proxy: scrollViewProxy, animated: false)
            }
        } catch {
            print("❌ Error fetching messages: \(error)")
            errorMessage = "Failed to load messages: \(error.localizedDescription)"
        }
        isLoadingMessages = false
    }

    @MainActor
    func sendMessage() {
        guard let userId = currentUserId, !newMessageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard !isSendingMessage else { return }

        let textToSend = newMessageText.trimmingCharacters(in: .whitespaces)
        newMessageText = ""
        isSendingMessage = true

        Task {
            let params = NewMessageParams(chatId: chat.id, senderId: userId, content: textToSend)
            do {
                try await supabase.from("messages").insert(params, returning: .minimal).execute()
                print("✅ Message sent successfully.")
            } catch {
                print("❌ Error sending message: \(error)")
                errorMessage = "Failed to send message: \(error.localizedDescription)"
                newMessageText = textToSend
            }
            isSendingMessage = false
        }
    }

    // Function to subscribe to new messages via Realtime
    @MainActor
    func subscribeToMessages() { // Made non-async
        guard self.channel == nil else {
            print("⚠️ Already subscribed or channel exists.")
            return
        }
        guard currentUserId != nil else {
            print("⚠️ Cannot subscribe: Current user ID not available.")
            return
        }

        // Channel topic format
        let channelTopic = "public:messages:chat_id=eq.\(chat.id)"
        print("Subscribing to channel topic: \(channelTopic)")

        // --- Corrected Realtime Subscription using .channel().on().subscribe() ---
        let newChannel = supabase.realtime.channel(channelTopic)

        // Define the callback closure (handler)
        let messageHandler = { (message: RealtimeMessage) in // Renamed to handler
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

        // ****** FIX: Correct .on() signature assuming event: String, filter: ChannelFilter, handler: Callback ******
        // Construct the ChannelFilter object WITHOUT the event
        let channelFilter = ChannelFilter(
            // event: "INSERT", // Event is now the first parameter of .on()
            schema: "public",
            table: "messages",
            filter: "chat_id=eq.\(chat.id)" // The filter string
        )

        // Subscribe using the .on() method with event, filter object and handler
        newChannel.on("INSERT", filter: channelFilter, handler: messageHandler) // Use event:, filter:, handler: labels
        // ****** END FIX ******
        .subscribe { status, error in // Handle subscription status changes
            if let error = error {
                print("🔴 Realtime subscription error: \(error.localizedDescription)")
                Task { @MainActor in
                    self.errorMessage = "Realtime connection error."
                    self.channel = nil
                }
            } else {
                print("🟢 Realtime subscription status: \(status)")
                if status == .subscribed {
                    Task { @MainActor in
                         self.channel = newChannel
                    }
                }
            }
        }
        // --- End Corrected Realtime Subscription ---
    }


    // Function to unsubscribe from Realtime channel
    @MainActor
    func unsubscribeFromMessages() async {
        guard let currentChannel = self.channel else { return }
        print("Unsubscribing from channel: \(currentChannel.topic)")
        do {
            try await currentChannel.unsubscribe()
            self.channel = nil
            print("✅ Successfully unsubscribed.")
        } catch {
            print("🔴 Error unsubscribing from channel: \(error)")
            self.channel = nil
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

    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedCorner(radius: 12, corners: [.topLeft, .topRight, .bottomLeft]))
            } else {
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemGray5))
                    .foregroundColor(Color(UIColor.label))
                    .clipShape(RoundedCorner(radius: 12, corners: [.topLeft, .topRight, .bottomRight]))
                Spacer()
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
        ChatDetailView(chat: sampleChat)
    }
}
