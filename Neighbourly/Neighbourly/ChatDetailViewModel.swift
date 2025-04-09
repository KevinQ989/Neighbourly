//
//  ChatDetailViewModel.swift
//  Neighbourly
//
//  Created by timothy lim on 10/4/25.
//


// ChatDetailViewModel.swift

import SwiftUI
import Supabase
import Combine

@MainActor // Ensure all updates happen on the main thread
class ChatDetailViewModel: ObservableObject {

    // MARK: - Published Properties (State for the View)
    @Published var chatData: Chat // The core chat data, including offer/review state
    @Published var messages: [ChatMessage] = []
    @Published var associatedRequest: RequestData? = nil
    @Published var currentUserId: UUID?

    // Loading States
    @Published var isLoadingMessages = false
    @Published var isLoadingRequest = false
    @Published var isLoadingOffer = false
    @Published var isLoadingAccept = false

    // Error States
    @Published var messageError: String? // Specific error for messages
    @Published var actionError: String? // Specific error for offer/accept actions
    @Published var requestError: String? // Specific error for associated request

    // Realtime
    private var channel: RealtimeChannel? = nil
    private var listenerTask: Task<Void, Never>? = nil

    // Dependencies (passed in)
    private let initialChat: Chat // Keep the original immutable chat if needed for reference

    // JSON Decoder
    private var jsonDecoder: JSONDecoder {
        // ... (copy the jsonDecoder computed property from ChatDetailView) ...
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

    // MARK: - Initializer
    init(chat: Chat) {
        self.initialChat = chat
        self._chatData = Published(initialValue: chat) // Initialize published chatData
        print("ViewModel Initialized for chat ID: \(chat.id)")
    }

    // MARK: - Setup and Teardown
    func setupChat() async {
        print("ViewModel: setupChat started")
        if currentUserId == nil { await fetchCurrentUserId() }
        guard currentUserId != nil else {
            messageError = "Could not identify current user."
            return
        }
        // Fetch initial data concurrently
        async let messagesTask: () = fetchMessages()
        async let detailsTask: () = fetchChatDetails() // Fetch latest state on appear
        async let requestTask: () = fetchAssociatedRequest()
        async let readStatusTask: () = markChatAsRead()

        _ = await [messagesTask, detailsTask, requestTask, readStatusTask]

        subscribeToMessages()
        print("ViewModel: setupChat finished")
    }

    func cleanup() async {
        print("ViewModel: cleanup started")
        listenerTask?.cancel()
        await unsubscribeFromMessages()
        print("ViewModel: cleanup finished")
    }

    // MARK: - Data Fetching Functions (Moved from View)

    func fetchCurrentUserId() async {
        guard currentUserId == nil else { return }
        do {
            currentUserId = try await supabase.auth.session.user.id
            print("ViewModel: Fetched currentUserId: \(currentUserId!)")
        } catch {
            print("❌ ViewModel: Error fetching current user ID: \(error)")
            messageError = "Could not identify current user."
        }
    }

    func fetchMessages() async {
        guard !isLoadingMessages else { return }
        isLoadingMessages = true
        messageError = nil
        print("ViewModel: Fetching messages for chat \(chatData.id)")
        do {
            let fetchedMessages: [ChatMessage] = try await supabase
                .from("messages")
                .select()
                .eq("chat_id", value: chatData.id)
                .order("created_at", ascending: true)
                .execute()
                .value
            self.messages = fetchedMessages
            print("ViewModel: Fetched \(fetchedMessages.count) messages.")
        } catch {
            print("❌ ViewModel: Error fetching messages: \(error)")
            messageError = "Failed to load messages: \(error.localizedDescription)"
        }
        isLoadingMessages = false
    }

    func fetchChatDetails() async {
        print("🔄 ViewModel [fetchChatDetails] Starting fetch for chat \(chatData.id)...")
        actionError = nil
        do {
             struct ChatDetails: Decodable { // Keep local decoding struct
                 let id: Int; let requestId: Int?; let requesterId: UUID; let helperId: UUID
                 let createdAt: Date; let offerMadeAt: Date?; let offerAcceptedAt: Date?
                 let helperReviewedAt: Date?; let requesterReviewedAt: Date?
                 enum CodingKeys: String, CodingKey {
                     case id; case requestId = "request_id"; case requesterId = "requester_id"
                     case helperId = "helper_id"; case createdAt = "created_at"
                     case offerMadeAt = "offer_made_at"; case offerAcceptedAt = "offer_accepted_at"
                     case helperReviewedAt = "helper_reviewed_at"; case requesterReviewedAt = "requester_reviewed_at"
                 }
             }
            print("   ViewModel [fetchChatDetails] Executing query...")
            let fetchedDetails: ChatDetails = try await supabase
                .from("chats")
                .select("id, request_id, requester_id, helper_id, created_at, offer_made_at, offer_accepted_at, helper_reviewed_at, requester_reviewed_at")
                .eq("id", value: chatData.id)
                .single()
                .execute()
                .value
            print("   ViewModel [fetchChatDetails] Query successful. Decoding done.")
            print("   ViewModel [fetchChatDetails] Fetched offerMadeAt: \(fetchedDetails.offerMadeAt == nil ? "nil" : "Timestamp")")

            // Update the @Published chatData property directly
            // This should trigger UI updates reliably
            self.chatData.offerMadeAt = fetchedDetails.offerMadeAt
            self.chatData.offerAcceptedAt = fetchedDetails.offerAcceptedAt
            self.chatData.helperReviewedAt = fetchedDetails.helperReviewedAt
            self.chatData.requesterReviewedAt = fetchedDetails.requesterReviewedAt
            // Update other fields if necessary, though less likely to change
            // self.chatData.requesterId = fetchedDetails.requesterId // Should not change
            // self.chatData.helperId = fetchedDetails.helperId // Should not change

            print("   ViewModel [fetchChatDetails] Updated @Published chatData. New isOfferMade = \(self.chatData.isOfferMade)")
            print("✅ ViewModel [fetchChatDetails] Chat details refreshed successfully.")

        } catch {
            print("❌ ViewModel [fetchChatDetails] Error refreshing chat details: \(error)")
            if let decodingError = error as? DecodingError {
                 print("   ViewModel [fetchChatDetails] Decoding Error Details: \(decodingError)")
            }
            messageError = "Failed to update chat status: \(error.localizedDescription)"
        }
    }

    func fetchAssociatedRequest() async {
        guard let reqId = chatData.requestId else { return }
        guard associatedRequest == nil, !isLoadingRequest else { return }
        isLoadingRequest = true
        requestError = nil
        print("ViewModel: Fetching associated request \(reqId)")
        do {
            let fetchedRequest: RequestData = try await supabase
                .from("requests")
                .select()
                .eq("id", value: reqId)
                .single()
                .execute()
                .value
            self.associatedRequest = fetchedRequest
            print("ViewModel: Fetched associated request.")
        } catch {
            print("❌ ViewModel: Error fetching associated request \(reqId): \(error)")
            requestError = "Failed to load associated request."
        }
        isLoadingRequest = false
    }

    func markChatAsRead() async {
        guard let userId = currentUserId else { return }
        print("ViewModel: Marking chat \(chatData.id) as read for user \(userId)")
        do {
            struct ReadStatusParams: Encodable { let chat_id: Int; let user_id: UUID; let last_read_at: Date }
            let params = ReadStatusParams(chat_id: chatData.id, user_id: userId, last_read_at: Date())
            try await supabase.from("chat_read_status").upsert(params, onConflict: "chat_id, user_id").execute()
            print("ViewModel: Marked chat as read.")
        } catch {
            print("❌ ViewModel: Error marking chat as read - \(error)")
        }
    }

    // MARK: - Action Functions (Moved from View)

    func performMakeOffer() async {
        guard !isLoadingOffer, let currentUserId = currentUserId else { return }
        guard currentUserId == chatData.helperId else {
            actionError = "Only the helper can make an offer."
            return
        }
        isLoadingOffer = true
        actionError = nil
        print("ViewModel: performMakeOffer started")
        do {
            let params = MakeOfferRPCParams(chat_id_param: chatData.id, helper_id_param: currentUserId)
            try await supabase.rpc("make_offer_for_chat", params: params).execute()
            print("ViewModel: performMakeOffer RPC successful. Fetching details...")
            await fetchChatDetails() // Refresh state
        } catch {
            print("❌ ViewModel: Error making offer - \(error)")
            actionError = "Failed to make offer: \(error.localizedDescription)"
        }
        isLoadingOffer = false
        print("ViewModel: performMakeOffer finished")
    }

    func performAcceptOffer() async {
        guard !isLoadingAccept, let currentUserId = currentUserId else { return }
        guard currentUserId == chatData.requesterId else {
            actionError = "Only the requester can accept an offer."
            return
        }
        guard chatData.isOfferMade else {
            actionError = "Cannot accept offer before one is made."
            return
        }
        guard !chatData.isOfferAccepted else {
             actionError = "Offer has already been accepted."
             return
        }
        isLoadingAccept = true
        actionError = nil
        print("ViewModel: performAcceptOffer started")
        do {
            let params = AcceptOfferRPCParams(chat_id_param: chatData.id, requester_id_param: currentUserId)
            try await supabase.rpc("accept_offer_for_chat", params: params).execute()
            print("ViewModel: performAcceptOffer RPC successful. Fetching details...")
            await fetchChatDetails() // Refresh state
        } catch {
            print("❌ ViewModel: Error accepting offer - \(error)")
            actionError = "Failed to accept offer: \(error.localizedDescription)"
        }
        isLoadingAccept = false
        print("ViewModel: performAcceptOffer finished")
    }

    // MARK: - Realtime Functions (Moved from View)

    func subscribeToMessages() {
        guard self.channel == nil else { return }
        guard currentUserId != nil else { return }

        let channelTopic = "public:messages:chat_id=eq.\(chatData.id)"
        print("ViewModel: Subscribing to \(channelTopic)")
        let newChannel = supabase.realtime.channel(channelTopic)

        let messageHandler = { [weak self] (message: RealtimeMessage) in
            guard let self = self else { return }
            print("ViewModel: Realtime message received")
            // ... (copy message handling logic from ChatDetailView, updating self.messages) ...
            guard message.payload["type"] as? String == "INSERT",
                  let recordPayload = message.payload["record"] as? [String: Any] else { return }
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: recordPayload)
                let newMessage = try self.jsonDecoder.decode(ChatMessage.self, from: jsonData)
                Task { @MainActor in // Ensure UI update is on main thread
                    if !self.messages.contains(where: { $0.id == newMessage.id }) {
                        self.messages.append(newMessage)
                        // Maybe scroll to bottom here? Needs ScrollViewProxy passed or handled differently
                    }
                }
            } catch {
                print("🔴 ViewModel: Realtime decode error: \(error)")
            }
        }

        let channelFilter = ChannelFilter(event: "INSERT", schema: "public", table: "messages", filter: "chat_id=eq.\(chatData.id)")

        newChannel.on("INSERT", filter: channelFilter, handler: messageHandler)
        .subscribe { [weak self] status, error in
            guard let self = self else { return }
            if let error = error {
                print("🔴 ViewModel: Realtime subscription error: \(error.localizedDescription)")
                self.messageError = "Realtime connection error."
                self.channel = nil
            } else {
                print("🟢 ViewModel: Realtime subscription status: \(status)")
                if status == .subscribed {
                    self.channel = newChannel
                }
            }
        }
    }

    func unsubscribeFromMessages() async {
        guard let currentChannel = self.channel else { return }
        print("ViewModel: Unsubscribing from \(currentChannel.topic)")
        do {
            try await currentChannel.unsubscribe()
            self.channel = nil
            print("ViewModel: Unsubscribed successfully.")
        } catch {
            print("🔴 ViewModel: Error unsubscribing - \(error)")
            self.channel = nil
        }
    }

    // MARK: - Send Message (Moved from View)
    // Note: Needs access to the text field binding, usually passed as parameter

    func sendMessage(text: String, clearTextField: @escaping () -> Void) { // Pass text and callback
        guard let userId = currentUserId, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        // Add isSendingMessage state if needed in ViewModel

        let textToSend = text.trimmingCharacters(in: .whitespaces)
        clearTextField() // Call the callback to clear UI

        // Optimistic UI (optional, can be handled purely by Realtime)
        // ...

        Task {
            let params = NewMessageParams(chatId: chatData.id, senderId: userId, content: textToSend)
            do {
                try await supabase.from("messages").insert(params, returning: .minimal).execute()
                print("ViewModel: Message sent.")
            } catch {
                print("❌ ViewModel: Error sending message: \(error)")
                messageError = "Failed to send message."
                // Revert optimistic UI if used
            }
            // Reset isSendingMessage state if used
        }
    }
}
