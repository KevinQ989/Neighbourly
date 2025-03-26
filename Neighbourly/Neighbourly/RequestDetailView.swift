// RequestDetailView.swift

import SwiftUI
import Supabase
import CoreLocation // Import CoreLocation for coordinates

struct RequestDetailView: View { // Brace 1 Open
    // Input: The request to display
    let request: RequestData

    // State for profile fetch
    @State private var requesterProfile: Profile?
    @State private var isLoadingProfile = false
    @State private var profileError: String?

    // State for chat initiation
    @State private var chatToNavigate: Chat? = nil // Holds the chat object for navigation
    @State private var isInitiatingChat = false
    @State private var chatError: String?
    @State private var currentUserId: UUID? // Store current user ID

    // Environment for presentation mode (to dismiss if needed)
    @Environment(\.dismiss) var dismiss

    var body: some View { // Brace 2 Open
        // Use a ZStack to overlay NavigationLink
        ZStack {
            // Background NavigationLink for chat
            // Activated when chatToNavigate is set
            // Use NavigationLink initializer that takes item: Binding<Item?>
            // This requires Chat to be Hashable (ensure it is in Models.swift)
            NavigationLink(
                destination: chatDestination, // Use computed property for destination
                isActive: Binding( // Still using isActive for now
                    get: { chatToNavigate != nil },
                    set: { isActive in if !isActive { chatToNavigate = nil } }
                ),
                label: { EmptyView() }
            )
            .opacity(0) // Keep it invisible

            // Main ScrollView content
            ScrollView { // Brace 3 Open
                VStack(alignment: .leading, spacing: 20) { // Brace 4 Open

                    // --- Image Section ---
                    AsyncImage(url: URL(string: request.imageUrl ?? "")) { phase in
                         switch phase {
                         case .empty:
                             Rectangle()
                                 .fill(Color.gray.opacity(0.1))
                                 .aspectRatio(16/9, contentMode: .fit)
                                 .overlay(ProgressView())
                                 .cornerRadius(10)
                         case .success(let image):
                             image
                                 .resizable()
                                 .aspectRatio(contentMode: .fill) // Or .fit depending on desired look
                                 // Add max height if needed, or rely on aspectRatio
                                 // .frame(maxHeight: 300)
                                 .cornerRadius(10)
                         case .failure:
                             Rectangle()
                                 .fill(Color.gray.opacity(0.1))
                                 .aspectRatio(16/9, contentMode: .fit)
                                 .overlay(Image(systemName: "photo").font(.largeTitle).foregroundColor(.gray))
                                 .cornerRadius(10)
                         @unknown default:
                             EmptyView()
                         }
                     }
                     // --- End Updated Image Section ---

                    // --- Title and Category ---
                    VStack(alignment: .leading) { // Brace 5 Open
                        Text(request.title)
                            .font(.title)
                            .fontWeight(.bold)
                        if let category = request.category { // Brace 6 Open
                            Text(category)
                                .font(.subheadline)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        } // Brace 6 Close
                    } // Brace 5 Close

                    Divider()

                    // --- Description ---
                    VStack(alignment: .leading) { // Brace 7 Open
                        Text("Description")
                            .font(.headline)
                        Text(request.description ?? "No description provided.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    } // Brace 7 Close

                    Divider()

                    // --- Requester Info ---
                    VStack(alignment: .leading) { // Brace 8 Open
                        Text("Requested By")
                            .font(.headline)
                        if isLoadingProfile { // Brace 9 Open
                            ProgressView()
                        } else if let profile = requesterProfile { // Brace 9 Close, Brace 10 Open
                            HStack { // Brace 11 Open
                                Image(systemName: "person.circle.fill") // Placeholder Avatar
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.gray)
                                VStack(alignment: .leading) { // Brace 12 Open
                                    Text(profile.fullName ?? profile.username ?? "Unknown User")
                                        .fontWeight(.semibold)
                                } // Brace 12 Close
                            } // Brace 11 Close
                        } else { // Brace 10 Close, Brace 13 Open
                            Text("User ID: \(request.userId.uuidString.prefix(8))...")
                                .foregroundColor(.gray)
                            if let profileError { // Brace 14 Open
                                Text("Error loading profile: \(profileError)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } // Brace 14 Close
                        } // Brace 13 Close
                    } // Brace 8 Close

                    Divider()

                    // --- Other Details ---
                    VStack(alignment: .leading, spacing: 8) { // Brace 15 Open
                        HStack { // Brace 16 Open
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text("Complete By:")
                            Text(request.completeBy?.formatted(date: .abbreviated, time: .shortened) ?? "Not specified")
                        } // Brace 16 Close
                        HStack { // Brace 17 Open
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text("Location:")
                            Text(request.locationText ?? "Not specified")
                        } // Brace 17 Close
                        if let coordinate = request.coordinate {
                             HStack {
                                 Image(systemName: "map.pin.ellipse")
                                     .foregroundColor(.green)
                                 Text("Coords:")
                                 Text("Lat: \(coordinate.latitude, specifier: "%.4f"), Lon: \(coordinate.longitude, specifier: "%.4f")")
                                     .font(.caption)
                             }
                        }
                        HStack { // Brace 18 Open
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Status:")
                            Text(request.status.capitalized)
                        } // Brace 18 Close
                    } // Brace 15 Close
                    .font(.subheadline)

                    // Display Chat Error if any
                    if let chatError {
                        Text("Chat Error: \(chatError)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top)
                    }

                    Spacer() // Push button to bottom

                    // --- Action Button ---
                    let isMyOwnRequest = (request.userId == currentUserId)
                    Button { // Brace 19 Open
                        Task { await initiateOrFindChat() }
                    } label: { // Brace 19 Close
                        HStack { // Use HStack for potential ProgressView
                            Spacer()
                            if isInitiatingChat {
                                ProgressView().tint(.white)
                            } else {
                                // Button text depends only on whether it's user's own request
                                Text(isMyOwnRequest ? "View My Request" : "Chat with Requester")
                            }
                            Spacer()
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        // Disable if own request OR initiating chat
                        .background(isMyOwnRequest || isInitiatingChat ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    // Disable interaction if own request or initiating chat
                    .disabled(isMyOwnRequest || isInitiatingChat)

                } // Brace 4 Close
                .padding() // Add padding to the VStack content
            } // Brace 3 Close
        } // End ZStack
        .navigationTitle("Request Details") // Set navigation title
        .navigationBarTitleDisplayMode(.inline)
        .task { // Fetch requester profile and current user ID when view appears
            await fetchCurrentUserId() // Fetch current user first
            await fetchRequesterProfile()
        }
        .onAppear { // Also fetch current user ID on appear
             Task { await fetchCurrentUserId() }
        }
    } // Brace 2 Close

    // Computed property for the destination view
    @ViewBuilder
    private var chatDestination: some View {
        if let chat = chatToNavigate {
            ChatDetailView(chat: chat)
        } else {
            EmptyView() // Should not happen if link is active
        }
    }

    // Function to get current user ID
    @MainActor
    func fetchCurrentUserId() async {
        guard currentUserId == nil else { return }
        do {
            currentUserId = try await supabase.auth.session.user.id
        } catch {
            print("❌ Error fetching current user ID: \(error)")
        }
    }

    // Function to fetch the profile of the user who made the request
    @MainActor
    func fetchRequesterProfile() async {
        guard requesterProfile == nil, !isLoadingProfile else { return }
        isLoadingProfile = true
        profileError = nil
        do {
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: request.userId)
                .single()
                .execute()
                .value
            self.requesterProfile = profile
            print("Fetched profile for user: \(profile.username ?? profile.id.uuidString)")
        } catch {
            print("❌ Error fetching requester profile: \(error)")
            self.profileError = error.localizedDescription
        }
        isLoadingProfile = false
    }


    // --- Function to Initiate or Find Chat ---
    @MainActor
    func initiateOrFindChat() async {
        guard let currentUserId = self.currentUserId else {
            chatError = "Could not identify current user."
            return
        }
        guard request.userId != currentUserId else {
            print("Cannot initiate chat for own request.")
            return
        }
        guard let requesterProfile = self.requesterProfile else {
             chatError = "Requester profile not loaded yet."
             return
        }

        isInitiatingChat = true
        chatError = nil
        chatToNavigate = nil

        do {
            // 1. Check if a chat already exists using the simpler query
            struct BasicChatInfo: Decodable, Identifiable {
                let id: Int
                let requesterId: UUID
                let helperId: UUID
                let createdAt: Date
            }

            // Use the simpler query for BasicChatInfo
            let existingBasicChats: [BasicChatInfo] = try await supabase
                .from("chats")
                .select("id, requester_id, helper_id, created_at")
                .eq("request_id", value: request.id)
                // Ensure BOTH users are involved in the chat for this request
                .or("and(requester_id.eq.\(currentUserId),helper_id.eq.\(request.userId)),and(requester_id.eq.\(request.userId),helper_id.eq.\(currentUserId))")
                .limit(1)
                .execute()
                .value

            if let existingChatInfo = existingBasicChats.first {
                // Chat exists!
                print("Found existing chat (ID: \(existingChatInfo.id))")

                // The other participant is the request owner, whose profile we already fetched.
                let otherParticipantProfile = requesterProfile

                self.chatToNavigate = Chat(
                    id: existingChatInfo.id,
                    requestId: request.id,
                    otherParticipant: otherParticipantProfile, // Use the correct profile
                    createdAt: existingChatInfo.createdAt
                )

            } else {
                // Chat doesn't exist, create it
                print("No existing chat found. Creating new chat...")
                let newChatParams = NewChatParams(
                    requestId: request.id,
                    requesterId: request.userId, // Request owner is the requester
                    helperId: currentUserId      // Current user is the helper
                )

                struct CreatedChatInfo: Decodable {
                     let id: Int
                     let createdAt: Date
                }

                let createdChatInfo: CreatedChatInfo = try await supabase
                    .from("chats")
                    .insert(newChatParams, returning: .representation)
                    .select("id, created_at")
                    .single()
                    .execute()
                    .value

                print("Created new chat (ID: \(createdChatInfo.id))")
                // The other participant is the request owner
                self.chatToNavigate = Chat(
                    id: createdChatInfo.id,
                    requestId: request.id,
                    otherParticipant: requesterProfile,
                    createdAt: createdChatInfo.createdAt
                )
            }
            // Navigation is handled by the NavigationLink reacting to chatToNavigate change

        } catch {
            print("❌ Error initiating or finding chat: \(error)")
            chatError = "Could not start chat: \(error.localizedDescription)"
        }

        isInitiatingChat = false
    }
    // --- End Initiate or Find Chat ---

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
