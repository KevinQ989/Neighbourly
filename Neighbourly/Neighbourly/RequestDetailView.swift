// RequestDetailView.swift

import SwiftUI
import Supabase
import CoreLocation

struct RequestDetailView: View { // Brace 1 Open
    // Input & State
    let request: RequestData
    @State private var requesterProfile: Profile?
    @State private var isLoadingProfile = false
    @State private var profileError: String?
    @State private var chatToNavigate: Chat? = nil
    @State private var isInitiatingChat = false
    @State private var chatError: String?
    @State private var currentUserId: UUID?
    @Environment(\.dismiss) var dismiss

    var body: some View { // Brace 2 Open
        ZStack {
            // Background NavigationLink
            NavigationLink(destination: chatDestination, isActive: Binding(get: { chatToNavigate != nil }, set: { isActive in if !isActive { chatToNavigate = nil } }), label: { EmptyView() }).opacity(0)

            // Main ScrollView content
            ScrollView { // Brace 3 Open
                VStack(alignment: .leading, spacing: 20) { // Brace 4 Open

                    // --- Updated Image Section ---
                    AsyncImage(url: URL(string: request.imageUrl ?? "")) { phase in
                         switch phase {
                         case .empty: ZStack { Rectangle().fill(Color.gray.opacity(0.1)).aspectRatio(16/9, contentMode: .fit); ProgressView() }.cornerRadius(10)
                         case .success(let image): image.resizable().aspectRatio(contentMode: .fill).frame(maxHeight: 350).clipped().cornerRadius(10)
                         case .failure: ZStack { Rectangle().fill(Color.gray.opacity(0.1)).aspectRatio(16/9, contentMode: .fit); Image(systemName: "photo.fill").resizable().scaledToFit().frame(width: 60, height: 60).foregroundColor(.gray) }.cornerRadius(10)
                         @unknown default: EmptyView()
                         }
                     }
                     // --- End Updated Image Section ---

                    // --- Title and Category ---
                    VStack(alignment: .leading) { Text(request.title).font(.title).fontWeight(.bold); if let category = request.category { Text(category).font(.subheadline).padding(.horizontal, 8).padding(.vertical, 4).background(Color.blue.opacity(0.1)).foregroundColor(.blue).cornerRadius(8) } } // Brace 5, 6
                    Divider()
                    // --- Description ---
                    VStack(alignment: .leading) { Text("Description").font(.headline); Text(request.description ?? "No description provided.").font(.body).foregroundColor(.secondary) } // Brace 7
                    Divider()
                    // --- Requester Info ---
                    VStack(alignment: .leading) { // Brace 8 Open
                        Text("Requested By").font(.headline)
                        if isLoadingProfile { ProgressView() } // Brace 9
                        else if let profile = requesterProfile { // Brace 10 Open
                            HStack { // Brace 11 Open
                                // Use AsyncImage for Avatar
                                AsyncImage(url: URL(string: profile.avatarUrl ?? "")) { phase in
                                     switch phase {
                                     case .empty: Image(systemName: "person.circle.fill").resizable().foregroundColor(.gray).overlay(ProgressView().scaleEffect(0.5))
                                     case .success(let image): image.resizable()
                                     case .failure: Image(systemName: "person.circle.fill").resizable().foregroundColor(.gray)
                                     @unknown default: EmptyView()
                                     }
                                 }
                                 .scaledToFit().frame(width: 40, height: 40).clipShape(Circle()).overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                                VStack(alignment: .leading) { Text(profile.fullName ?? profile.username ?? "Unknown User").fontWeight(.semibold) } // Brace 12
                            } // Brace 11 Close
                        } else { Text("User ID: \(request.userId.uuidString.prefix(8))...").foregroundColor(.gray); if let profileError { Text("Error: \(profileError)").font(.caption).foregroundColor(.red) } } // Brace 13, 14
                    } // Brace 8 Close
                    // --- End Updated Requester Info ---
                    Divider()
                    // --- Other Details ---
                    VStack(alignment: .leading, spacing: 8) { // Brace 15 Open
                        HStack { Image(systemName: "calendar").foregroundColor(.blue); Text("Complete By:"); Text(request.completeBy?.formatted(date: .abbreviated, time: .shortened) ?? "Not specified") } // Brace 16
                        HStack { Image(systemName: "location.fill").foregroundColor(.blue); Text("Location:"); Text(request.locationText ?? "Not specified") } // Brace 17
                        if let coordinate = request.coordinate { HStack { Image(systemName: "map.pin.ellipse").foregroundColor(.green); Text("Coords:"); Text("Lat: \(coordinate.latitude, specifier: "%.4f"), Lon: \(coordinate.longitude, specifier: "%.4f")").font(.caption) } }
                        HStack { Image(systemName: "info.circle").foregroundColor(.blue); Text("Status:"); Text(request.status.capitalized) } // Brace 18
                    } // Brace 15 Close
                    .font(.subheadline)
                    if let chatError { Text("Chat Error: \(chatError)").font(.caption).foregroundColor(.red).padding(.top) }
                    Spacer()
                    // --- Action Button ---
                    let isMyOwnRequest = (request.userId == currentUserId)
                    Button { Task { await initiateOrFindChat() } } label: { HStack { Spacer(); if isInitiatingChat { ProgressView().tint(.white) } else { Text(isMyOwnRequest ? "View My Request" : "Chat with Requester") }; Spacer() }.fontWeight(.semibold).frame(maxWidth: .infinity).padding().background(isMyOwnRequest || isInitiatingChat ? Color.gray : Color.blue).foregroundColor(.white).cornerRadius(10) } // Brace 19
                    .disabled(isMyOwnRequest || isInitiatingChat)

                } // Brace 4 Close
                .padding()
            } // Brace 3 Close
        } // End ZStack
        .navigationTitle("Request Details").navigationBarTitleDisplayMode(.inline)
        .task { await fetchCurrentUserId(); await fetchRequesterProfile() }
        .onAppear { Task { await fetchCurrentUserId() } }
    } // Brace 2 Close

    @ViewBuilder private var chatDestination: some View {
        if let chat = chatToNavigate {
            ChatDetailView(chat: chat)
        } else {
            EmptyView()
        }
    }
    
    @MainActor func fetchCurrentUserId() async {
        guard currentUserId == nil else {
            return
        };
        do {
            currentUserId = try await supabase.auth.session.user.id
        } catch {
            print("❌ Error fetching current user ID: \(error)")
        }
    }
    
    @MainActor func fetchRequesterProfile() async {
        guard requesterProfile == nil, !isLoadingProfile else {
            return
        };
        isLoadingProfile = true;
        profileError = nil;
        do {
            let profile: Profile = try await supabase.from("profiles").select().eq("id", value: request.userId).single().execute().value; self.requesterProfile = profile; print("Fetched profile for user: \(profile.username ?? profile.id.uuidString)")
        } catch {
            print("❌ Error fetching requester profile: \(error)"); self.profileError = error.localizedDescription
        };
        isLoadingProfile = false
    }
    @MainActor
    func initiateOrFindChat() async {
        // --- Guard Clauses (Keep as is) ---
        guard let currentUserId = self.currentUserId else {
            chatError = "Could not identify current user."
            return
        }
        guard request.userId != currentUserId else {
            print("Cannot initiate chat for own request.")
            // Optionally provide user feedback if needed
            // chatError = "You cannot chat about your own request."
            return
        }
        guard let requesterProfile = self.requesterProfile else {
            chatError = "Requester profile not loaded yet."
            return
        }
        // --- End Guard Clauses ---

        isInitiatingChat = true
        chatError = nil
        chatToNavigate = nil // Ensure navigation state is reset

        // Define struct for decoding chat info (used for both SELECT and INSERT return)
        // Make sure this matches your 'chats' table columns accurately
        struct ChatInfo: Decodable, Identifiable {
            let id: Int
            let requestId: Int? // Include if needed from SELECT/INSERT return
            let requesterId: UUID
            let helperId: UUID
            let createdAt: Date

            enum CodingKeys: String, CodingKey {
                case id
                case requestId = "request_id"
                case requesterId = "requester_id"
                case helperId = "helper_id"
                case createdAt = "created_at"
            }
        }

        do {
            // 1. Check for existing chat
            print("Checking for existing chat for request ID: \(request.id)")
            let existingChats: [ChatInfo] = try await supabase
                .from("chats")
                .select("id, request_id, requester_id, helper_id, created_at") // Select columns matching ChatInfo
                .eq("request_id", value: request.id)
                // Ensure OR condition correctly checks both user roles
                .or("and(requester_id.eq.\(currentUserId),helper_id.eq.\(request.userId)),and(requester_id.eq.\(request.userId),helper_id.eq.\(currentUserId))")
                .limit(1)
                .execute()
                .value // Decode into [ChatInfo]

            if let existingChatInfo = existingChats.first {
                // --- Existing Chat Found ---
                print("Found existing chat (ID: \(existingChatInfo.id))")
                // Use the already loaded requesterProfile as the other participant
                self.chatToNavigate = Chat(
                    id: existingChatInfo.id,
                    requestId: existingChatInfo.requestId, // Use value from fetched chat info
                    otherParticipant: requesterProfile,
                    createdAt: existingChatInfo.createdAt
                    // Last message details would typically be fetched separately or via join
                )
                // --- End Existing Chat Found ---

            } else {
                // --- No Existing Chat - Create New One ---
                print("No existing chat found. Creating new chat...")
                let newChatParams = NewChatParams(
                    requestId: request.id,
                    requesterId: request.userId, // The user who posted the request
                    helperId: currentUserId      // The current user initiating the chat
                )

                // Insert and expect the full representation back, decode into ChatInfo
                let createdChatInfo: ChatInfo = try await supabase
                    .from("chats")
                    .insert(newChatParams, returning: .representation) // Ask for the whole row back
                    // No .select() needed here if returning: .representation gives full row
                    .single() // Expect only one row returned from insert
                    .execute()
                    .value // Decode the single returned row into ChatInfo

                print("Created new chat (ID: \(createdChatInfo.id))")
                // Use the already loaded requesterProfile as the other participant
                self.chatToNavigate = Chat(
                    id: createdChatInfo.id,
                    requestId: createdChatInfo.requestId, // Use value from created chat info
                    otherParticipant: requesterProfile,
                    createdAt: createdChatInfo.createdAt
                )
                // --- End Create New One ---
            }
        } catch {
            print("❌ Error initiating or finding chat: \(error)")
            // Check if it's a decoding error specifically
            if let decodingError = error as? DecodingError {
                 print("--> Decoding Error Details: \(decodingError)")
                 chatError = "Could not process chat data response. (\(error.localizedDescription))"
            } else {
                 chatError = "Could not start chat: \(error.localizedDescription)"
            }
        }
        isInitiatingChat = false
    }

} // Brace 1 Close

// MARK: - Preview Provider
#Preview {
    // Create some sample RequestData for the preview
    let sampleCoordinate = CLLocationCoordinate2D(latitude: 1.35, longitude: 103.8)
    let sampleGeoPoint = GeoJSONPoint(coordinate: sampleCoordinate)

    let sampleRequest = RequestData(
        id: 1,
        userId: UUID(), // Generate a random UUID for preview
        title: "Need Help Moving Sofa",
        description: "Looking for one strong person to help me move a 3-seater sofa down one flight of stairs this Saturday.",
        category: "Moving Help",
        completeBy: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
        locationText: "123 Main St, Apt 4B",
        locationGeo: sampleGeoPoint,
        imageUrl: nil, // No image for preview
        status: "open",
        createdAt: Date()
    )

    // Embed in NavigationView for the preview to show title bar
    NavigationView {
        RequestDetailView(request: sampleRequest)
    }
}
