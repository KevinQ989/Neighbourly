// ChatView.swift

import SwiftUI
import Supabase // <-- Import

// ChatFilter enum remains the same
enum ChatFilter {
    case all //, requests, offers // Simplify for now, filtering logic needs rework with new model
}

// Updated ChatRow to use the new Chat model
struct ChatRow: View {
    let chat: Chat // Use the new Chat model

    var body: some View {
        HStack {
            // Display other participant's avatar (placeholder)
            // TODO: Load avatar from chat.otherParticipant.avatarUrl
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(.gray)
                .clipShape(Circle())

            VStack(alignment: .leading) {
                HStack {
                    // Display other participant's name
                    Text(chat.otherParticipant.fullName ?? chat.otherParticipant.username ?? "Unknown User")
                        .font(.headline)
                    Spacer()
                    // Display chat creation time (or last message time later)
                    Text(chat.createdAt, style: .time) // Example: Show time
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                // Display last message preview (placeholder)
                Text("Last message preview...") // TODO: Fetch/display last message
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            Spacer()

            // Optional: Display related request image (placeholder)
            // Requires fetching request details based on chat.requestId
            Image(systemName: "archivebox.fill") // Placeholder
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundColor(.gray.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 8)
    }
}


struct ChatView: View { // Brace 1 Open
    // State for filters, fetched chats, loading, errors
    @State private var selectedTab: ChatFilter = .all // Keep filter state if needed later
    @State private var chats: [Chat] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    // State for navigation
    @State private var selectedChat: Chat? = nil // Store the whole Chat object for navigation
    // Note: NavigationLink using isActive binding is less reliable in newer SwiftUI versions.
    // Consider using .navigationDestination(for: Chat.self) in iOS 16+

    // Filtered chats (simplified for now)
    var filteredChats: [Chat] {
        // TODO: Re-implement filtering based on request association if needed
        return chats
    }

    var body: some View { // Brace 2 Open
        // Use the NavigationView provided by TabBarView
        // NavigationView { // <-- REMOVE
            VStack(spacing: 0) { // Use spacing 0 for seamless list

                // Filter Buttons (Keep UI, functionality needs rework later)
                /* // Commenting out filter buttons for now as logic needs update
                HStack {
                    FilterButton(title: "All", isSelected: selectedTab == .all) { selectedTab = .all }
                    // FilterButton(title: "Your Requests", ...)
                    // FilterButton(title: "Your Offers", ...)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.systemGroupedBackground)) // Add background
                 */

                // Handle Loading/Error/Empty States
                if isLoading { // Brace 3 Open
                    ProgressView("Loading Chats...")
                        .frame(maxHeight: .infinity)
                } else if let errorMessage { // Brace 3 Close, Brace 4 Open
                    VStack { // Brace 5 Open
                        Text("Error loading chats:")
                        Text(errorMessage).foregroundColor(.red).font(.caption)
                        Button("Retry") { Task { await fetchChats() } }
                            .padding(.top)
                    } // Brace 5 Close
                    .frame(maxHeight: .infinity)
                } else if chats.isEmpty { // Brace 4 Close, Brace 6 Open
                    Text("No chats yet.")
                        .foregroundColor(.gray)
                        .frame(maxHeight: .infinity)
                } else { // Brace 6 Close, Brace 7 Open
                    // List of Chats
                    List { // Use List directly
                        ForEach(chats) { chat in // Use ForEach within List
                            // Use NavigationLink directly as the row content
                            // This is simpler for basic navigation
                            NavigationLink(destination: ChatDetailView(chat: chat)) {
                                ChatRow(chat: chat)
                            }
                        }
                    } // End List
                    .listStyle(PlainListStyle()) // Use PlainListStyle
                } // Brace 7 Close
            } // End VStack
            .navigationTitle("Chats")
            // .navigationBarTitleDisplayMode(.inline) // Optional: Use inline title
            .task { // Fetch chats when the view appears
                await fetchChats()
            }
        // } // <-- REMOVE (End of removed NavigationView)
    } // Brace 2 Close

    // Function to fetch chats from Supabase
    @MainActor
    func fetchChats() async { // Brace 11 Open
        isLoading = true
        errorMessage = nil
        // chats = [] // Optionally clear chats while loading

        do { // Brace 12 Open
            // 1. Get current user ID
            let currentUserId = try await supabase.auth.session.user.id

            // --- Simpler Approach: Fetch Chats, then Profiles ---

            // Fetch basic chat info where user is involved
            // Define struct locally if only used here
            struct BasicChatInfo: Decodable, Identifiable {
                let id: Int
                let requestId: Int?
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

            let basicChats: [BasicChatInfo] = try await supabase
                .from("chats")
                .select("id, request_id, requester_id, helper_id, created_at")
                .or("requester_id.eq.\(currentUserId),helper_id.eq.\(currentUserId)")
                .order("created_at", ascending: false) // Or order by updated_at later
                .execute()
                .value

            // Now, for each chat, determine the other user's ID and fetch their profile
            var populatedChats: [Chat] = []
            for basicChat in basicChats { // Brace 13 Open
                let otherUserId = (basicChat.requesterId == currentUserId) ? basicChat.helperId : basicChat.requesterId

                // Fetch the other user's profile
                do { // Brace 14 Open (Profile fetch do-catch)
                    let otherProfile: Profile = try await supabase
                        .from("profiles")
                        .select("id, username, full_name, avatar_url") // Select fields matching Profile struct
                        .eq("id", value: otherUserId)
                        .single() // Expect exactly one profile
                        .execute()
                        .value

                    // Create the final Chat object
                    let chat = Chat(
                        id: basicChat.id,
                        requestId: basicChat.requestId,
                        otherParticipant: otherProfile,
                        createdAt: basicChat.createdAt
                    )
                    populatedChats.append(chat)
                } catch { // Brace 14 Close, Brace 15 Open
                    print("❌ Could not fetch profile for user \(otherUserId) in chat \(basicChat.id): \(error)")
                    // Optionally skip this chat or create a Chat object with placeholder profile
                    // Example: Create with a placeholder profile
                    let placeholderProfile = Profile(id: otherUserId, username: "Unknown", fullName: "Unknown User", website: nil, avatarUrl: nil)
                    let chat = Chat(
                        id: basicChat.id,
                        requestId: basicChat.requestId,
                        otherParticipant: placeholderProfile,
                        createdAt: basicChat.createdAt
                    )
                    populatedChats.append(chat) // Add chat even if profile fetch failed
                } // Brace 15 Close
            } // Brace 13 Close

            self.chats = populatedChats
            print("Fetched \(populatedChats.count) chats.")

        } catch { // Brace 12 Close, Brace 16 Open
            print("❌ Error fetching chats: \(error)")
            self.errorMessage = error.localizedDescription
        } // Brace 16 Close

        isLoading = false
    } // Brace 11 Close

} // Brace 1 Close


// FilterButton struct (Keep if using filters later)
struct FilterButton: View { // Brace 17 Open
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View { // Brace 18 Open
        Button(action: action) { // Brace 19 Open
            Text(title)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.black : Color.white)
                .foregroundColor(isSelected ? .white : .black)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
        } // Brace 19 Close
    } // Brace 18 Close
} // Brace 17 Close


// Preview Provider
#Preview { // Brace 20 Open
    // Create sample data matching the *new* Chat model for preview
    let sampleOtherProfile = Profile(id: UUID(), username: "sampleUser", fullName: "Sample User", website: nil, avatarUrl: nil)
    let sampleChat = Chat(id: 1, requestId: 1, otherParticipant: sampleOtherProfile, createdAt: Date())
    let sampleChat2 = Chat(id: 2, requestId: 2, otherParticipant: sampleOtherProfile, createdAt: Date().addingTimeInterval(-3600))

    // Embed in NavigationView for preview context
    NavigationView { // Brace 21 Open
        // Provide sample data directly to the view for preview
        // Need to initialize ChatView correctly if it expects bindings or state objects
        // For simple preview with fetched data, we can inject sample data if needed
        // Or just let it run its fetch logic (might fail in preview)
         ChatView() // Let preview run fetch logic or show loading/empty state
        // ChatView(chats: [sampleChat, sampleChat2]) // Alternative: Inject sample data
    } // Brace 21 Close
} // Brace 20 Close
