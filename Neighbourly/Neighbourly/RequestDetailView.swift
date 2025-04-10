// RequestDetailView.swift

import SwiftUI
import Supabase
import CoreLocation

// --- InitialMessageSheetView (Keep as is) ---
struct InitialMessageSheetView: View {
    // Input properties
    let chatId: Int
    let currentUserId: UUID
    let otherParticipant: Profile // For display
    let request: RequestData // To display context

    // State
    @State private var messageText: String = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    // Environment
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView { // Embed in NavigationView for title and toolbar
            VStack(spacing: 15) {
                // Display Request Context
                HStack {
                    AsyncImage(url: URL(string: request.imageUrl ?? "")) { phase in
                        switch phase {
                        case .empty: ZStack { Rectangle().fill(Color.gray.opacity(0.1)); ProgressView() }
                        case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                        case .failure: ZStack { Rectangle().fill(Color.gray.opacity(0.1)); Image(systemName: "photo.fill").foregroundColor(.gray) }
                        @unknown default: EmptyView()
                        }
                    }
                    .frame(width: 60, height: 60).clipped().cornerRadius(8)

                    VStack(alignment: .leading) {
                        Text("Regarding Request:")
                            .font(.caption).foregroundColor(.gray)
                        Text(request.title)
                            .font(.headline).lineLimit(1)
                        Text("To: \(otherParticipant.fullName ?? otherParticipant.username ?? "User")")
                            .font(.subheadline)
                    }
                    Spacer()
                }
                .padding(.bottom)

                // Message Input
                TextEditor(text: $messageText)
                    .frame(height: 150)
                    .border(Color(UIColor.systemGray4))
                    .cornerRadius(5)

                // Error Message Display
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer() // Push button to bottom

                // Send Button
                Button {
                    Task { await sendMessage() }
                } label: {
                    HStack {
                        Spacer()
                        if isSending {
                            ProgressView().tint(.white)
                        } else {
                            Text("Send Initial Message")
                        }
                        Spacer()
                    }
                    .fontWeight(.semibold)
                    .padding()
                    .background(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)

            }
            .padding()
            .navigationTitle("Start Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // Function to send the initial message
    @MainActor
    func sendMessage() async {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isSending else { return }

        print("➡️ InitialMessageSheet: Send button tapped.") // Debug Log
        isSending = true
        errorMessage = nil

        let params = NewMessageParams(
            chatId: self.chatId,
            senderId: self.currentUserId,
            content: messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        do {
            print("➡️ InitialMessageSheet: Sending message to Supabase...") // Debug Log
            try await supabase.from("messages").insert(params, returning: .minimal).execute()
            print("✅ InitialMessageSheet: Message sent successfully for chat \(chatId). Dismissing sheet.") // Debug Log
            dismiss() // Close the sheet on success
        } catch {
            print("❌ InitialMessageSheet: Error sending message - \(error)") // Debug Log
            errorMessage = "Failed to send message: \(error.localizedDescription)"
            isSending = false // Allow retry
        }
        print("➡️ InitialMessageSheet: sendMessage finished. isSending = \(isSending)")
    }
}
// --- END InitialMessageSheetView ---


struct RequestDetailView: View {
    @Environment(\.isAuthenticatedValue) private var isViewAuthenticated
    // Input & State
    let request: RequestData
    @State private var requesterProfile: Profile? // Keep state for fetched profile
    @State private var isLoadingProfile = false
    @State private var profileError: String?
    @State private var isInitiatingChat = false
    @State private var chatError: String?
    @State private var currentUserId: UUID?
    @Environment(\.dismiss) var dismiss
    @State private var showingInitialMessageSheet = false
    @State private var chatInfoForSheet: (chatId: Int, otherParticipant: Profile)? = nil
    @State private var chatToNavigate: Chat? = nil
    @State private var isLoadingCloseRequest = false
    @State private var showingConfirmation = false

    var body: some View {
        ZStack {
            // Background NavigationLink (Unchanged)
            NavigationLink(
                destination: chatDestinationView,
                isActive: Binding( get: { chatToNavigate != nil }, set: { isActive in if !isActive { chatToNavigate = nil } } ),
                label: { EmptyView() }
            )
            .opacity(0)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Image Section (Unchanged)
                    AsyncImage(url: URL(string: request.imageUrl ?? "")) { phase in
                        switch phase {
                        case .empty: ZStack { Rectangle().fill(Color.gray.opacity(0.1)).aspectRatio(16/9, contentMode: .fit); ProgressView() }.cornerRadius(10)
                        case .success(let image): image.resizable().aspectRatio(contentMode: .fill).frame(maxHeight: 350).clipped().cornerRadius(10)
                        case .failure: ZStack { Rectangle().fill(Color.gray.opacity(0.1)).aspectRatio(16/9, contentMode: .fit); Image(systemName: "photo.fill").resizable().scaledToFit().frame(width: 60, height: 60).foregroundColor(.gray) }.cornerRadius(10)
                        @unknown default: EmptyView()
                        }
                    }

                    // Title and Category (Unchanged)
                    VStack(alignment: .leading) { Text(request.title).font(.title).fontWeight(.bold); if let category = request.category { Text(category).font(.subheadline).padding(.horizontal, 8).padding(.vertical, 4).background(Color.blue.opacity(0.1)).foregroundColor(.blue).cornerRadius(8) } }
                    Divider()
                    // Description (Unchanged)
                    VStack(alignment: .leading) { Text("Description").font(.headline); Text(request.description ?? "No description provided.").font(.body).foregroundColor(.secondary) }
                    Divider()

                    // **** UPDATED: Requester Info Section ****
                    VStack(alignment: .leading) {
                        Text("Requested By").font(.headline)
                        if isLoadingProfile {
                            ProgressView() // Show loader while fetching
                        } else if let profile = requesterProfile {
                            // Wrap the HStack in a NavigationLink
                            NavigationLink(destination: ProfileView(userId: profile.id)) { // Pass requester's ID
                                HStack { // The content of the link
                                    AsyncImage(url: URL(string: profile.avatarUrl ?? "")) { phase in
                                        switch phase {
                                        case .empty: Image(systemName: "person.circle.fill").resizable().foregroundColor(.gray).overlay(ProgressView().scaleEffect(0.5))
                                        case .success(let image): image.resizable()
                                        case .failure: Image(systemName: "person.circle.fill").resizable().foregroundColor(.gray)
                                        @unknown default: EmptyView()
                                        }
                                    }
                                    .scaledToFit().frame(width: 40, height: 40).clipShape(Circle()).overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                                    VStack(alignment: .leading) {
                                        Text(profile.fullName ?? profile.username ?? "Unknown User").fontWeight(.semibold)
                                            .foregroundColor(Color.primary) // Ensure text is visible
                                    }
                                    Spacer() // Push chevron to the right if needed, or remove if just tapping row
                                    Image(systemName: "chevron.right").foregroundColor(.secondary) // Indicate navigation
                                }
                            }
                            .buttonStyle(.plain) // Make link look like plain content
                        } else {
                            // Error or placeholder state (Unchanged)
                            Text("User ID: \(request.userId.uuidString.prefix(8))...").foregroundColor(.gray)
                            if let profileError { Text("Error: \(profileError)").font(.caption).foregroundColor(.red) }
                        }
                    }
                    // **** END UPDATED Requester Info Section ****

                    Divider()
                    // Other Details (Unchanged)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Image(systemName: "calendar").foregroundColor(.blue); Text("Complete By:"); Text(request.completeBy?.formatted(date: .abbreviated, time: .shortened) ?? "Not specified") }
                        HStack { Image(systemName: "location.fill").foregroundColor(.blue); Text("Location:"); Text(request.locationText ?? "Not specified") }
                        if let coordinate = request.coordinate { HStack { Image(systemName: "map.pin.ellipse").foregroundColor(.green); Text("Coords:"); Text("Lat: \(coordinate.latitude, specifier: "%.4f"), Lon: \(coordinate.longitude, specifier: "%.4f")").font(.caption) } }
                        HStack { Image(systemName: "info.circle").foregroundColor(.blue); Text("Status:"); Text(request.open ? "Open" : "Closed") }
                    }
                    .font(.subheadline)

                    // Chat Error Display (Unchanged)
                    if let chatError { Text("Chat Error: \(chatError)").font(.caption).foregroundColor(.red).padding(.top) }

                    Spacer() // Push button down

                    // Action Button (Unchanged logic)
                    let isMyOwnRequest = (request.userId == currentUserId)
                    let requestIsClosed = !request.open
                    if !requestIsClosed {
                        Button {
                            if isMyOwnRequest { // If it's your own request, close it
                                showingConfirmation = true
                            } else { // Otherwise, initiate/find chat
                                Task { await initiateOrFindChat() }
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if isLoadingCloseRequest {
                                    ProgressView().tint(.white) // Loader if closing request
                                }
                                else if isInitiatingChat { ProgressView().tint(.white) } // or finding chat

                                else {
                                    Text(isMyOwnRequest ? "Close Request" : "Chat with Requester")
                                }
                                Spacer()
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isMyOwnRequest ? (isLoadingCloseRequest ? .gray : .red) : (isInitiatingChat ? .gray : .blue))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled((isMyOwnRequest && isLoadingCloseRequest) || (!isMyOwnRequest && isInitiatingChat) )
                    } else {
                        Text("Request Closed")
                             .fontWeight(.semibold)
                             .frame(maxWidth: .infinity)
                             .padding()
                             .background(Color.gray)
                             .foregroundColor(.white)
                             .cornerRadius(10)
                    }

                } // End Main VStack
                .padding()
            } // End ScrollView
        } // End ZStack
        .navigationTitle("Request Details")
        .navigationBarTitleDisplayMode(.inline)
        .task { // Fetch data (Unchanged)
            await fetchCurrentUserId()
            await fetchRequesterProfile()
        }
        // .onAppear removed as fetchCurrentUserId is in .task
        .sheet(isPresented: $showingInitialMessageSheet) {
            // Ensure chatInfoForSheet is not nil before presenting
            if let chatInfo = chatInfoForSheet, let userId = currentUserId {
                InitialMessageSheetView(
                    chatId: chatInfo.chatId,
                    currentUserId: userId,
                    otherParticipant: chatInfo.otherParticipant,
                    request: request // Pass the request for context
                )
            } else {
                // Fallback or error view if needed, though guards should prevent this
                Text("Error preparing chat sheet.")
            }
        }
        .alert(isPresented: $showingConfirmation) {
            Alert(
                title: Text("Confirm Close Request"),
                message: Text("Are you sure you want to close this request?"),
                primaryButton: .destructive(Text("Close Request")) {
                    Task { await closeRequest() } // Close only if confirmed
                },
                secondaryButton: .cancel() // User cancels
            )
        }
    } // End body

    // chatDestinationView (Unchanged)
    @ViewBuilder
    private var chatDestinationView: some View {
        // Only construct ChatDetailView if chatToNavigate is set
        if let chat = chatToNavigate {
            ChatDetailView(chat: chat)
        } else {
            // Should ideally not be reached if isActive binding is correct
            EmptyView()
        }
    }

    // fetchCurrentUserId (Unchanged)
    @MainActor func fetchCurrentUserId() async {
        guard isViewAuthenticated else {
            print("❌ RequestDetailView fetchCurrentUserId: View not authenticated.")
            return
        }
        guard currentUserId == nil else { return }
        do {
            currentUserId = try await supabase.auth.session.user.id
        } catch {
            print("❌ Error fetching current user ID: \(error)") } }

    // fetchRequesterProfile (Unchanged)
    @MainActor func fetchRequesterProfile() async { guard requesterProfile == nil, !isLoadingProfile else { return }; isLoadingProfile = true; profileError = nil; do { let profile: Profile = try await supabase.from("profiles").select().eq("id", value: request.userId).single().execute().value; self.requesterProfile = profile; print("Fetched profile for user: \(profile.username ?? profile.id.uuidString)") } catch { print("❌ Error fetching requester profile: \(error)"); self.profileError = error.localizedDescription }; isLoadingProfile = false }

    // initiateOrFindChat (Unchanged)
    @MainActor
    func initiateOrFindChat() async {
        guard isViewAuthenticated else {
            print("❌ RequestDetailView initiateOrFindChat: View not authenticated.")
            chatError = "You must be logged in to start a chat."
            return
        }
        guard let currentUserId = self.currentUserId else {
            chatError = "Could not identify current user."
            return
        }
        guard request.userId != currentUserId else {
            print("Cannot initiate chat for own request.")
            chatError = "You cannot chat about your own request." // Provide feedback
            return
        }
        guard let requesterProfile = self.requesterProfile else {
            chatError = "Requester profile not loaded yet."
            return
        }

        print("➡️ initiateOrFindChat: Starting...")

        isInitiatingChat = true
        chatError = nil
        chatToNavigate = nil // Reset navigation state
        chatInfoForSheet = nil // Reset sheet state

        // Define struct for decoding chat info including state fields
        struct ChatInfo: Decodable, Identifiable {
            let id: Int
            let requestId: Int?
            let requesterId: UUID
            let helperId: UUID
            let createdAt: Date
            // --- ADDED State Fields ---
            let offerMadeAt: Date?
            let offerAcceptedAt: Date?
            let helperReviewedAt: Date?
            let requesterReviewedAt: Date?
            // --- END ADDED ---
            // --- ADD Request Details ---
            struct RequestInfo: Decodable {
                let title: String?
                let imageUrl: String?
                enum CodingKeys: String, CodingKey { case title; case imageUrl = "image_url" }
            }
            let requests: RequestInfo? // This property holds the nested request info
            // --- END Request Details ---
            enum CodingKeys: String, CodingKey {
                case id; case requestId = "request_id"; case requesterId = "requester_id"
                case helperId = "helper_id"; case createdAt = "created_at"
                // --- ADDED Keys ---
                case offerMadeAt = "offer_made_at"
                case offerAcceptedAt = "offer_accepted_at"
                case helperReviewedAt = "helper_reviewed_at"
                case requesterReviewedAt = "requester_reviewed_at"
                // --- END ADDED ---
                case requests // Key matches table name
            }
        }

        do {
            // 1. Check for existing chat FOR THIS SPECIFIC REQUEST
            print("➡️ initiateOrFindChat: Checking for existing chat for Request ID \(request.id)")
            let existingChats: [ChatInfo] = try await supabase
                .from("chats")
                // Include request details AND state fields in select
                .select("""
                    id, request_id, requester_id, helper_id, created_at,
                    offer_made_at, offer_accepted_at, helper_reviewed_at, requester_reviewed_at,
                    requests(title, image_url)
                """)
                .eq("request_id", value: request.id) // Filter by request_id
                .or("and(requester_id.eq.\(currentUserId),helper_id.eq.\(request.userId)),and(requester_id.eq.\(request.userId),helper_id.eq.\(currentUserId))")
                .limit(1)
                .execute()
                .value

            if let existingChatInfo = existingChats.first {
                // --- Existing Chat Found for this Request -> NAVIGATE ---
                print("➡️ initiateOrFindChat: Found existing chat ID \(existingChatInfo.id) for this request. Navigating...")

                // --- CORRECTED Chat object creation ---
                // Create the Chat object needed for ChatDetailView
                let chatForNav = Chat(
                    id: existingChatInfo.id,
                    requestId: existingChatInfo.requestId,
                    otherParticipant: requesterProfile, // We already fetched this
                    createdAt: existingChatInfo.createdAt,
                    // Fetch last message separately if needed, or rely on ChatDetailView fetch
                    requestTitle: existingChatInfo.requests?.title, // Pass request info
                    requestImageUrl: existingChatInfo.requests?.imageUrl,
                    // --- ADD arguments here ---
                    requesterId: existingChatInfo.requesterId, // Get from existingChatInfo
                    helperId: existingChatInfo.helperId,       // Get from existingChatInfo
                    // Pass the state fields fetched from the DB as well
                    offerMadeAt: existingChatInfo.offerMadeAt,
                    offerAcceptedAt: existingChatInfo.offerAcceptedAt,
                    helperReviewedAt: existingChatInfo.helperReviewedAt,
                    requesterReviewedAt: existingChatInfo.requesterReviewedAt
                    // --- END ADD ---
                )
                // --- END CORRECTED Chat object creation ---

                // Set the state variable to trigger the NavigationLink
                self.chatToNavigate = chatForNav
                // --- END NAVIGATE ---
            } else {
                // --- No Chat for this Request -> CREATE NEW & SHOW SHEET ---
                print("➡️ initiateOrFindChat: No existing chat for request \(request.id). Creating new one...")
                let newChatParams = NewChatParams(
                    requestId: request.id, // MUST associate with this request
                    requesterId: request.userId,
                    helperId: currentUserId
                )

                // Insert and get the new chat ID back
                struct CreatedChatId: Decodable { let id: Int }
                let createdChat: CreatedChatId = try await supabase
                    .from("chats")
                    .insert(newChatParams, returning: .representation)
                    .select("id")
                    .single()
                    .execute()
                    .value

                print("➡️ initiateOrFindChat: Created new chat ID \(createdChat.id)")

                // Prepare and show the sheet for the *new* chat ID
                self.chatInfoForSheet = (chatId: createdChat.id, otherParticipant: requesterProfile)
                self.showingInitialMessageSheet = true
                // --- END CREATE NEW & SHOW SHEET ---
            }
        } catch {
            print("❌ initiateOrFindChat: Error - \(error)")
            if let decodingError = error as? DecodingError {
                print("--> Decoding Error Details: \(decodingError)")
                chatError = "Could not process chat data response. (\(error.localizedDescription))"
            } else {
                chatError = "Could not start chat: \(error.localizedDescription)"
            }
        }
        isInitiatingChat = false
        print("➡️ initiateOrFindChat: Finished. isInitiatingChat = \(isInitiatingChat)")
    }
    // --- END initiateOrFindChat ---

    // closeRequest (Unchanged)
    @MainActor
    func closeRequest() async {
        guard isViewAuthenticated else {
            print("❌ RequestDetailView closeRequest: View not authenticated.")
            return
        }
        isLoadingCloseRequest = true
        print("Attempting to close request with ID: \(request.id)")
        print("Current userId: \(String(describing: currentUserId))")
        do {
            let updateRequest: [RequestData] = try await supabase.from("requests")
                .update(["open": false])
                .eq("id", value: request.id)
                .execute()
                .value
            if updateRequest.count > 0 {
                print("Number of closed requests is greater than 0")
                print("Re-fetching RequestData to update UI") // Or update local state
                print("Closed request ID \(request.id) successfully")
                // Consider dismissing the view or updating local request state
                // dismiss() // Example
            }
        } catch {
            print("❌ Error updating request on table - \(error)")
        }
        isLoadingCloseRequest = false
    }

} // End RequestDetailView struct
