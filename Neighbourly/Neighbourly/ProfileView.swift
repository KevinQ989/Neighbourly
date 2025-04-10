// ProfileView.swift

import SwiftUI
import Supabase

// MARK: - Card Views (Keep as they are)
struct RequestCardView: View { /* ... No changes needed ... */
    let request: RequestData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AsyncImage(url: URL(string: request.imageUrl ?? "")) { phase in
                switch phase {
                case .empty: ZStack { Rectangle().fill(Color.gray.opacity(0.1)); ProgressView() }
                case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                case .failure: ZStack { Rectangle().fill(Color.gray.opacity(0.1)); Image(systemName: "photo.fill").foregroundColor(.gray) }
                @unknown default: EmptyView()
                }
            }
            .frame(height: 150).clipped()
            
            VStack(alignment: .leading, spacing: 8) {
                Text(request.title).font(.headline).fontWeight(.semibold).lineLimit(1)
                Text(request.description ?? "No description").font(.body).lineLimit(2).foregroundColor(.secondary)
                Text(request.createdAt, style: .date).font(.caption).foregroundColor(.gray)
            }
            .padding()
        }
        .frame(width: 250, alignment: .leading).background(Color(.systemGray6)).cornerRadius(10).shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct ReviewCardView: View { /* ... No changes needed ... */
    let review: Review
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                AsyncImage(url: URL(string: review.reviewerImageUrl ?? "")) { phase in
                    switch phase {
                    case .empty:
                        Image(systemName: "person.crop.circle.fill").resizable().aspectRatio(contentMode: .fill).frame(width: 40, height: 40).clipShape(Circle()).foregroundColor(.gray).padding(.trailing, 8) // Small progress
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill).frame(width: 40, height: 40).clipShape(Circle()).foregroundColor(.gray).padding(.trailing, 8)
                    case .failure:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(review.reviewerName ?? "Unknown User") // Provide default value
                        .font(.headline).fontWeight(.bold)
                    HStack(spacing: 2) { ForEach(0..<5) { index in Image(systemName: index < review.rating ? "star.fill" : "star").foregroundColor(index < review.rating ? .yellow : .gray) } }
                    Text(review.description ?? "No comment") // Use 'description' as per your preference, provide default
                        .font(.body).lineLimit(2).foregroundColor(.secondary)
                }
            }
        }
        .padding().frame(width: 250, alignment: .leading).background(Color(.systemGray6)).cornerRadius(10).shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Detailed List Views (Keep as they are)
struct AllHelpRequestsView: View { /* ... No changes needed ... */
    let helpRequests: [RequestData]
    
    let columns: [GridItem] = [
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]
    
    var body: some View {
        VStack {
            Text("All Requests")
                .font(.title)
                .fontWeight(.bold)
            
            Spacer()
            // List of requests for this category
            if helpRequests.isEmpty {
                Spacer()
                Text("No requests posted")
                    .foregroundColor(.gray)
                Spacer()
            } else {
                ScrollView {  //Wrap LazyVGrid inside ScrollView
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(helpRequests) { request in
                            NavigationLink(destination: RequestDetailView(request: request)) {
                                RequestCard(request: request)  // Reuse RequestCard
                                    .padding(8)  // Add padding around each card
                            }
                        }
                    }
                    .padding()  // Add padding to the grid itself
                }
            }
        }
    }
}

struct AllReviewsView: View { /* ... No changes needed ... */
    let reviews: [Review] // From this view or a function

    var body: some View {
        List {
            ForEach(reviews) { review in //For the for each with list
                HStack(alignment: .top, spacing: 8) {
                    AsyncImage(url: URL(string: review.reviewerImageUrl ?? "")) { phase in
                        switch phase {
                        case .empty:
                            Image(systemName: "person.crop.circle.fill").resizable().aspectRatio(contentMode: .fill).frame(width: 40, height: 40).clipShape(Circle()).foregroundColor(.gray).padding(.trailing, 8) // Small progress
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill).frame(width: 40, height: 40).clipShape(Circle()).foregroundColor(.gray).padding(.trailing, 8)
                        case .failure:
                            Image(systemName: "person.crop.circle.fill")
                                .resizable().foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(review.reviewerName ?? "Unknown User") // Provide default value
                            .fontWeight(.bold)

                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { index in
                                Image(systemName: index < review.rating ? "star.fill" : "star")
                                    .foregroundColor(index < review.rating ? .yellow : .gray)
                            }
                        }

                        Text(review.description ?? "No comment") // Use 'description', provide default
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("All Reviews")
    }
}

// MARK: - Main Profile View (Refactored)

struct ProfileView: View {
    // **** ADDED: Input User ID (Optional) ****
    let userId: UUID? // If nil, show logged-in user's profile

    // State for fetched data
    @State private var profileToDisplay: Profile? = nil // Renamed from userProfile
    @State private var userRequests: [RequestData] = []
    @State private var reviews: [Review] = []
    @State private var isLoading = true // Start as true
    @State private var errorMessage: String?
    @State private var isLoadingReviews = false // Keep separate loading for reviews
    @State private var reviewsError: String?

    // **** ADDED: State to store logged-in user ID ****
    @State private var loggedInUserId: UUID? = nil

    // Computed property to determine which user ID to load data for
    private var targetUserId: UUID? {
        userId ?? loggedInUserId // Use provided userId if available, otherwise loggedInUserId
    }

    // Computed property to check if viewing own profile
    private var isViewingOwnProfile: Bool {
        guard let target = targetUserId, let loggedIn = loggedInUserId else {
            // If either is nil, we can't be sure, default to false (safer)
            // Or if userId input is nil, it implies own profile
            return userId == nil
        }
        return target == loggedIn
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle Loading/Error States
            if isLoading {
                ProgressView("Loading Profile...")
                    .frame(maxHeight: .infinity)
            } else if let errorMessage {
                VStack {
                    Text("Error loading profile:")
                    Text(errorMessage).foregroundColor(.red).font(.caption)
                    Button("Retry") { Task { await loadData() } } // Call combined loadData
                        .padding(.top)
                }
                .frame(maxHeight: .infinity)
            } else if let profile = profileToDisplay { // Use renamed state variable
                // Main content once profile is loaded
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // --- Profile Header ---
                        HStack(alignment: .center, spacing: 16) {
                            AsyncImage(url: URL(string: profile.avatarUrl ?? "")) { phase in /* ... */ } // Use profile.avatarUrl
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.fullName ?? "No Name") // Use profile.fullName
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text("@\(profile.username ?? "no_username")") // Use profile.username
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("No rating yet") // Placeholder rating
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            // **** ADDED: Conditional Edit Button ****
                            if isViewingOwnProfile {
                                NavigationLink(destination: EditProfileView(onProfileUpdated: {
                                    // Refresh profile data when EditProfileView updates it
                                    Task { await loadData() } // Call combined loadData
                                })) {
                                    Text("Edit Profile")
                                        .font(.subheadline)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .overlay(Capsule().stroke(Color.blue, lineWidth: 1))
                                }
                            }
                            // **** END Conditional Edit Button ****
                        }
                        .padding(.horizontal)
                        // --- End Profile Header ---

                        // Requests Section (Unchanged logic, uses userRequests state)
                        HStack {
                            Text(isViewingOwnProfile ? "My Requests" : "Requests") // Adjust title
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                            if !userRequests.isEmpty {
                                NavigationLink(destination: AllHelpRequestsView(helpRequests: userRequests)) {
                                    Text("See All")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.horizontal)

                        if userRequests.isEmpty {
                            Text(isViewingOwnProfile ? "You haven't posted any requests yet." : "This user hasn't posted any requests yet.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(userRequests.sorted { $0.createdAt > $1.createdAt }) { req in
                                        NavigationLink(destination: RequestDetailView(request: req)) {
                                            RequestCardView(request: req)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Reviews Section (Unchanged logic, uses reviews state)
                        HStack {
                            Text("Reviews")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                            if !reviews.isEmpty {
                                NavigationLink(destination: AllReviewsView(reviews: reviews)) {
                                    Text("See All")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.horizontal)

                        if isLoadingReviews {
                            ProgressView().padding(.horizontal)
                        } else if let reviewsError {
                            Text("Error loading reviews: \(reviewsError)")
                                .font(.caption).foregroundColor(.red).padding(.horizontal)
                        } else if reviews.isEmpty {
                            Text(isViewingOwnProfile ? "You haven't received any reviews yet." : "This user hasn't received any reviews yet.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(reviews) { review in
                                        ReviewCardView(review: review)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                    } // End Main VStack
                    .padding(.vertical)
                } // End ScrollView
            } else {
                // Fallback if profile is somehow nil after loading without error
                Text("Could not load profile.")
                    .frame(maxHeight: .infinity)
            }
        } // End Outer VStack
        .navigationTitle("Profile") // Keep generic title or adjust based on isViewingOwnProfile
        .navigationBarTitleDisplayMode(.inline)
        // **** UPDATED .task Modifier ****
        .task(id: userId) { // Re-run when the input userId changes
            await loadData()
        }
        // **** END UPDATED .task ****
    } // End body

    // **** ADDED: Combined Data Loading Function ****
    @MainActor
    func loadData() async {
        isLoading = true
        errorMessage = nil
        reviewsError = nil // Clear review error too
        profileToDisplay = nil // Clear previous profile
        userRequests = []
        reviews = []

        // 1. Get logged-in user ID if needed
        if loggedInUserId == nil {
            do {
                loggedInUserId = try await supabase.auth.session.user.id
            } catch {
                print("❌ Error fetching loggedInUserId: \(error)")
                errorMessage = "Could not verify current user session."
                isLoading = false
                return // Stop if we can't get logged-in user ID
            }
        }

        // 2. Determine the target user ID
        guard let idToLoad = targetUserId else {
            print("❌ Error: No target user ID available to load profile.")
            errorMessage = "Cannot determine which profile to load."
            isLoading = false
            return
        }
        print("➡️ Loading profile data for user ID: \(idToLoad)")

        // 3. Fetch Profile and Requests concurrently
        do {
            async let profileFetch: Profile = supabase.from("profiles")
                .select()
                .eq("id", value: idToLoad) // Use idToLoad
                .single()
                .execute()
                .value

            async let requestsFetch: [RequestData] = supabase.from("requests")
                .select()
                .eq("user_id", value: idToLoad) // Use idToLoad
                .order("created_at", ascending: false)
                .execute()
                .value

            let (profileResult, requestsResult) = try await (profileFetch, requestsFetch)
            self.profileToDisplay = profileResult
            self.userRequests = requestsResult
            print("   ✅ Fetched profile: \(profileResult.username ?? "N/A")")
            print("   ✅ Fetched \(requestsResult.count) requests.")

        } catch {
            print("❌ Error loading profile/requests data: \(error)")
            self.errorMessage = error.localizedDescription
            // Don't clear profile/requests here, let error message show
        }

        // 4. Fetch Reviews (can happen after profile/requests)
        await loadReviews(for: idToLoad) // Pass the target ID

        isLoading = false // Mark main loading as finished
    }
    // **** END Combined Data Loading Function ****


    // **** UPDATED: loadReviews Function ****
    @MainActor
    func loadReviews(for userIdToLoad: UUID) async { // Accept target user ID
        guard !isLoadingReviews else { return }
        isLoadingReviews = true
        reviewsError = nil
        print("➡️ loadReviews: Starting fetch for reviewee ID: \(userIdToLoad)")

        do {
            // Define struct for decoding joined data
            struct ReviewWithReviewer: Decodable, Identifiable { /* ... as before ... */
                let id: UUID; let chatId: Int; let requestId: Int?; let reviewerId: UUID
                let revieweeId: UUID; let rating: Int; let description: String?; let createdAt: Date
                struct ReviewerProfile: Decodable { let fullName: String?; let avatarUrl: String?
                    enum CodingKeys: String, CodingKey { case fullName = "full_name"; case avatarUrl = "avatar_url" }
                }
                let reviewer: ReviewerProfile?
                enum CodingKeys: String, CodingKey {
                    case id; case chatId = "chat_id"; case requestId = "request_id"
                    case reviewerId = "reviewerid"; case revieweeId = "revieweeid"
                    case rating; case description; case createdAt = "created_at"; case reviewer
                }
            }

            // Perform query joining reviews and profiles
            let fetchedReviewsWithProfile: [ReviewWithReviewer] = try await supabase.from("reviews")
                 .select("*, reviewer:reviewerid ( full_name, avatar_url )")
                 .eq("revieweeid", value: userIdToLoad) // Use userIdToLoad
                 .order("created_at", ascending: false)
                 .execute()
                 .value

            // Map fetched data to the Review model
            self.reviews = fetchedReviewsWithProfile.map { fetchedReview -> Review in
                 return Review(
                     id: fetchedReview.id, chatId: fetchedReview.chatId, requestId: fetchedReview.requestId,
                     reviewerId: fetchedReview.reviewerId, revieweeId: fetchedReview.revieweeId,
                     rating: fetchedReview.rating, description: fetchedReview.description, createdAt: fetchedReview.createdAt,
                     reviewerName: fetchedReview.reviewer?.fullName, reviewerImageUrl: fetchedReview.reviewer?.avatarUrl
                 )
             }
            print("✅ loadReviews: Successfully processed \(self.reviews.count) reviews.")

        } catch {
            print("❌ loadReviews: Error fetching reviews - \(error)")
            self.reviewsError = error.localizedDescription
            self.reviews = [] // Clear reviews on error
        }
        isLoadingReviews = false
    }
    // **** END UPDATED loadReviews Function ****

    // --- REMOVED loadProfileData function (logic merged into loadData) ---

} // End ProfileView struct

#Preview {
    // Preview logged-in user's profile
    NavigationView {
        ProfileView(userId: nil) // Pass nil to show logged-in user
    }
}

// Add a preview for viewing someone else's profile (optional)
#Preview("Other User Profile") {
    // Create a dummy UUID for preview
    let otherUserId = UUID()
    // Create a dummy profile to display initially (or show loading)
    let dummyProfile = Profile(id: otherUserId, username: "otherUser", fullName: "Other User Name", website: nil, avatarUrl: nil)

    return NavigationView {
        ProfileView(userId: otherUserId) // Pass the dummy ID
            // You might inject dummy data here for preview purposes if needed
            // .environmentObject(createDummyViewModel(for: otherUserId))
    }
}
