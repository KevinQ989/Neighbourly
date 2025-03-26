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

    @ViewBuilder private var chatDestination: some View { if let chat = chatToNavigate { ChatDetailView(chat: chat) } else { EmptyView() } }
    @MainActor func fetchCurrentUserId() async { guard currentUserId == nil else { return }; do { currentUserId = try await supabase.auth.session.user.id } catch { print("❌ Error fetching current user ID: \(error)") } }
    @MainActor func fetchRequesterProfile() async { guard requesterProfile == nil, !isLoadingProfile else { return }; isLoadingProfile = true; profileError = nil; do { let profile: Profile = try await supabase.from("profiles").select().eq("id", value: request.userId).single().execute().value; self.requesterProfile = profile; print("Fetched profile for user: \(profile.username ?? profile.id.uuidString)") } catch { print("❌ Error fetching requester profile: \(error)"); self.profileError = error.localizedDescription }; isLoadingProfile = false }
    @MainActor func initiateOrFindChat() async { guard let currentUserId = self.currentUserId else { chatError = "Could not identify current user."; return }; guard request.userId != currentUserId else { print("Cannot initiate chat for own request."); return }; guard let requesterProfile = self.requesterProfile else { chatError = "Requester profile not loaded yet."; return }; isInitiatingChat = true; chatError = nil; chatToNavigate = nil; do { struct BasicChatInfo: Decodable, Identifiable { let id: Int; let requesterId: UUID; let helperId: UUID; let createdAt: Date }; let existingBasicChats: [BasicChatInfo] = try await supabase.from("chats").select("id, requester_id, helper_id, created_at").eq("request_id", value: request.id).or("and(requester_id.eq.\(currentUserId),helper_id.eq.\(request.userId)),and(requester_id.eq.\(request.userId),helper_id.eq.\(currentUserId))").limit(1).execute().value; if let existingChatInfo = existingBasicChats.first { print("Found existing chat (ID: \(existingChatInfo.id))"); let otherParticipantProfile = requesterProfile; self.chatToNavigate = Chat(id: existingChatInfo.id, requestId: request.id, otherParticipant: otherParticipantProfile, createdAt: existingChatInfo.createdAt) } else { print("No existing chat found. Creating new chat..."); let newChatParams = NewChatParams(requestId: request.id, requesterId: request.userId, helperId: currentUserId); struct CreatedChatInfo: Decodable { let id: Int; let createdAt: Date }; let createdChatInfo: CreatedChatInfo = try await supabase.from("chats").insert(newChatParams, returning: .representation).select("id, created_at").single().execute().value; print("Created new chat (ID: \(createdChatInfo.id))"); self.chatToNavigate = Chat(id: createdChatInfo.id, requestId: request.id, otherParticipant: requesterProfile, createdAt: createdChatInfo.createdAt) } } catch { print("❌ Error initiating or finding chat: \(error)"); chatError = "Could not start chat: \(error.localizedDescription)" }; isInitiatingChat = false }

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
