// RequestDetailView.swift

import SwiftUI
import Supabase
import CoreLocation

// --- ADD THIS NEW VIEW STRUCT AT THE END OF THE FILE ---
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
        // --- Start: Add Debug Log ---
        // Note: isSending should be false here unless an error occurred
        print("➡️ InitialMessageSheet: sendMessage finished. isSending = \(isSending)")
        // --- End: Add Debug Log ---
    }
}
// --- END OF NEW VIEW STRUCT ---


struct RequestDetailView: View {
    @Environment(\.isAuthenticatedValue) private var isViewAuthenticated
    // Input & State
    let request: RequestData
    @State private var requesterProfile: Profile?
    @State private var isLoadingProfile = false
    @State private var profileError: String?
    // --- REMOVE chatToNavigate ---
    // @State private var chatToNavigate: Chat? = nil
    @State private var isInitiatingChat = false
    @State private var chatError: String?
    @State private var currentUserId: UUID?
    @Environment(\.dismiss) var dismiss

    // --- ADD State for Sheet Presentation ---
    @State private var showingInitialMessageSheet = false
    // Store info needed by the sheet
    @State private var chatInfoForSheet: (chatId: Int, otherParticipant: Profile)? = nil
    // --- END State for Sheet ---

    var body: some View {
        // --- REMOVE Background NavigationLink ---
        // ZStack { ... } is no longer needed unless for other overlays

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // --- Image Section (Keep as is) ---
                AsyncImage(url: URL(string: request.imageUrl ?? "")) { phase in
                     switch phase {
                     case .empty: ZStack { Rectangle().fill(Color.gray.opacity(0.1)).aspectRatio(16/9, contentMode: .fit); ProgressView() }.cornerRadius(10)
                     case .success(let image): image.resizable().aspectRatio(contentMode: .fill).frame(maxHeight: 350).clipped().cornerRadius(10)
                     case .failure: ZStack { Rectangle().fill(Color.gray.opacity(0.1)).aspectRatio(16/9, contentMode: .fit); Image(systemName: "photo.fill").resizable().scaledToFit().frame(width: 60, height: 60).foregroundColor(.gray) }.cornerRadius(10)
                     @unknown default: EmptyView()
                     }
                 }

                // --- Title and Category (Keep as is) ---
                VStack(alignment: .leading) { Text(request.title).font(.title).fontWeight(.bold); if let category = request.category { Text(category).font(.subheadline).padding(.horizontal, 8).padding(.vertical, 4).background(Color.blue.opacity(0.1)).foregroundColor(.blue).cornerRadius(8) } }
                Divider()
                // --- Description (Keep as is) ---
                VStack(alignment: .leading) { Text("Description").font(.headline); Text(request.description ?? "No description provided.").font(.body).foregroundColor(.secondary) }
                Divider()
                // --- Requester Info (Keep as is) ---
                VStack(alignment: .leading) {
                    Text("Requested By").font(.headline)
                    if isLoadingProfile { ProgressView() }
                    else if let profile = requesterProfile {
                        HStack {
                            AsyncImage(url: URL(string: profile.avatarUrl ?? "")) { phase in
                                 switch phase {
                                 case .empty: Image(systemName: "person.circle.fill").resizable().foregroundColor(.gray).overlay(ProgressView().scaleEffect(0.5))
                                 case .success(let image): image.resizable()
                                 case .failure: Image(systemName: "person.circle.fill").resizable().foregroundColor(.gray)
                                 @unknown default: EmptyView()
                                 }
                             }
                             .scaledToFit().frame(width: 40, height: 40).clipShape(Circle()).overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            VStack(alignment: .leading) { Text(profile.fullName ?? profile.username ?? "Unknown User").fontWeight(.semibold) }
                        }
                    } else { Text("User ID: \(request.userId.uuidString.prefix(8))...").foregroundColor(.gray); if let profileError { Text("Error: \(profileError)").font(.caption).foregroundColor(.red) } }
                }
                Divider()
                // --- Other Details (Keep as is) ---
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Image(systemName: "calendar").foregroundColor(.blue); Text("Complete By:"); Text(request.completeBy?.formatted(date: .abbreviated, time: .shortened) ?? "Not specified") }
                    HStack { Image(systemName: "location.fill").foregroundColor(.blue); Text("Location:"); Text(request.locationText ?? "Not specified") }
                    if let coordinate = request.coordinate { HStack { Image(systemName: "map.pin.ellipse").foregroundColor(.green); Text("Coords:"); Text("Lat: \(coordinate.latitude, specifier: "%.4f"), Lon: \(coordinate.longitude, specifier: "%.4f")").font(.caption) } }
                    HStack { Image(systemName: "info.circle").foregroundColor(.blue); Text("Status:"); Text(request.status.capitalized) }
                }
                .font(.subheadline)

                // --- Chat Error Display (Keep as is) ---
                if let chatError { Text("Chat Error: \(chatError)").font(.caption).foregroundColor(.red).padding(.top) }

                Spacer() // Push button down

                // --- Action Button (Keep as is, logic moved to initiateOrFindChat) ---
                let isMyOwnRequest = (request.userId == currentUserId)
                Button {
                    Task { await initiateOrFindChat() }
                } label: {
                    HStack {
                        Spacer()
                        if isInitiatingChat { ProgressView().tint(.white) }
                        // Button text remains the same, action changes
                        else { Text(isMyOwnRequest ? "View My Request" : "Chat with Requester") }
                        Spacer()
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isMyOwnRequest || isInitiatingChat ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isMyOwnRequest || isInitiatingChat) // Disable if own request or already processing

            } // End Main VStack
            .padding()
        } // End ScrollView
        .navigationTitle("Request Details")
        .navigationBarTitleDisplayMode(.inline)
        .task { // Keep tasks for fetching user/profile
            await fetchCurrentUserId()
            await fetchRequesterProfile()
        }
        .onAppear { // Keep onAppear fetch
            Task { await fetchCurrentUserId() }
        }
        // --- ADD Sheet Modifier ---
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
        // --- END Sheet Modifier ---
    } // End body

    // --- REMOVE chatDestination ---
    // @ViewBuilder private var chatDestination: some View { ... }

    // --- fetchCurrentUserId (Keep as is) ---
    @MainActor func fetchCurrentUserId() async {
        // --- ADD Check ---
        guard isViewAuthenticated else {
            print("❌ RequestDetailView fetchCurrentUserId: View not authenticated.")
            // Optionally set an error state specific to this view
            return
        }
        // --- END Check ---
        guard currentUserId == nil else { return }
        do {
            currentUserId = try await supabase.auth.session.user.id
        } catch {
            print("❌ Error fetching current user ID: \(error)") } }

    // --- fetchRequesterProfile (Keep as is) ---
    @MainActor func fetchRequesterProfile() async { guard requesterProfile == nil, !isLoadingProfile else { return }; isLoadingProfile = true; profileError = nil; do { let profile: Profile = try await supabase.from("profiles").select().eq("id", value: request.userId).single().execute().value; self.requesterProfile = profile; print("Fetched profile for user: \(profile.username ?? profile.id.uuidString)") } catch { print("❌ Error fetching requester profile: \(error)"); self.profileError = error.localizedDescription }; isLoadingProfile = false }

    // --- REPLACE initiateOrFindChat function ---
    @MainActor
    func initiateOrFindChat() async {
        // --- ADD Check ---
        guard isViewAuthenticated else {
            print("❌ RequestDetailView initiateOrFindChat: View not authenticated.")
            chatError = "You must be logged in to start a chat."
            return
        }
        // --- END Check ---
        // Guard clauses remain the same
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

        // Define struct for decoding chat info
        struct ChatInfo: Decodable, Identifiable {
            let id: Int
            let requestId: Int?
            let requesterId: UUID
            let helperId: UUID
            let createdAt: Date
            enum CodingKeys: String, CodingKey {
                case id; case requestId = "request_id"; case requesterId = "requester_id"
                case helperId = "helper_id"; case createdAt = "created_at"
            }
        }

        do {
            // 1. Check for existing chat (using user IDs, not request ID initially for consolidation)
            print("➡️ initiateOrFindChat: Checking for existing chat...")
            let existingChats: [ChatInfo] = try await supabase
                .from("chats")
                .select("id, request_id, requester_id, helper_id, created_at")
                // Find chat where users are requester/helper OR helper/requester
                .or("and(requester_id.eq.\(currentUserId),helper_id.eq.\(request.userId)),and(requester_id.eq.\(request.userId),helper_id.eq.\(currentUserId))")
                .limit(1)
                .execute()
                .value

            let chatInfo: ChatInfo // Declare variable to hold the result

            if let existingChatInfo = existingChats.first {
                // Existing Chat Found
                print("➡️ initiateOrFindChat: Found existing chat ID \(existingChatInfo.id)")
                chatInfo = existingChatInfo // Use the found chat info
            } else {
                // No Existing Chat - Create New One
                print("➡️ initiateOrFindChat: No existing chat found. Creating new one...")
                let newChatParams = NewChatParams(
                    requestId: request.id, // Associate with this specific request
                    requesterId: request.userId, // The user who posted the request
                    helperId: currentUserId      // The current user initiating the chat
                )

                // Insert and expect the full representation back
                let createdChatInfo: ChatInfo = try await supabase
                    .from("chats")
                    .insert(newChatParams, returning: .representation)
                    .single()
                    .execute()
                    .value
                print("➡️ initiateOrFindChat: Created new chat ID \(createdChatInfo.id)")
                chatInfo = createdChatInfo // Use the created chat info
            }
            
            // --- Prepare and show the sheet ---
            // We have the chat ID (chatInfo.id) and the other participant's profile (requesterProfile)
            self.chatInfoForSheet = (chatId: chatInfo.id, otherParticipant: requesterProfile)
            self.showingInitialMessageSheet = true // Trigger the sheet presentation
            // --- End prepare and show ---

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
        // --- Start: Add Debug Log ---
        // Note: isInitiatingChat should be false here unless an error occurred
        print("➡️ initiateOrFindChat: Finished. isInitiatingChat = \(isInitiatingChat)")
        // --- End: Add Debug Log ---
    }
    // --- END REPLACE initiateOrFindChat ---

} // End RequestDetailView struct
