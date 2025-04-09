// ProfileView.swift

import SwiftUI
import Supabase

// MARK: - Models (Local or Shared)

// Date Formatter
let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
}()



// MARK: - Card Views (Local to ProfileView for now)

// RequestCardView - Uses RequestData
struct RequestCardView: View {
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

// ReviewCardView
// **** THIS STRUCT IS UPDATED ****
struct ReviewCardView: View {
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
                    // --- CHANGE HERE: Use nil-coalescing ---
                    Text(review.reviewerName ?? "Unknown User") // Provide default value
                        .font(.headline).fontWeight(.bold)
                    // --- END CHANGE ---
                    HStack(spacing: 2) { ForEach(0..<5) { index in Image(systemName: index < review.rating ? "star.fill" : "star").foregroundColor(index < review.rating ? .yellow : .gray) } }
                    Text(review.description ?? "No comment") // Use 'description' as per your preference, provide default
                        .font(.body).lineLimit(2).foregroundColor(.secondary)
                }
            }
        }
        .padding().frame(width: 250, alignment: .leading).background(Color(.systemGray6)).cornerRadius(10).shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
// **** END UPDATED ReviewCardView ****

// MARK: - Detailed List Views (Local to ProfileView for now)
struct AllHelpRequestsView: View {
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

// AllReviewsView
// **** THIS STRUCT IS UPDATED ****
struct AllReviewsView: View {
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
                        // --- CHANGE HERE: Use nil-coalescing ---
                        Text(review.reviewerName ?? "Unknown User") // Provide default value
                            .fontWeight(.bold)
                        // --- END CHANGE ---

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
// **** END UPDATED AllReviewsView ****

// MARK: - Main Profile View (Updated)

struct ProfileView: View { // Brace 1 Open
    // State for fetched data
    @State private var userProfile: Profile? = nil
    @State private var userRequests: [RequestData] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var reviews: [Review] = []
    @State private var isLoadingReviews = false
    @State private var reviewsError: String?

    var body: some View { // Brace 2 Open
        VStack(spacing: 0) { // Brace 3 Open
            // Handle Loading/Error States for Profile
            if isLoading { // Brace 4 Open
                ProgressView("Loading Profile...")
                    .frame(maxHeight: .infinity)
            } else if let errorMessage { // Brace 4 Close, Brace 5 Open
                VStack { // Brace 6 Open
                    Text("Error loading profile:")
                    Text(errorMessage).foregroundColor(.red).font(.caption)
                    Button("Retry") { Task { await loadProfileData() } }
                        .padding(.top)
                } // Brace 6 Close
                .frame(maxHeight: .infinity)
            } else if let profile = userProfile { // Brace 5 Close, Brace 7 Open
                // Main content once profile is loaded
                ScrollView { // Brace 8 Open
                    VStack(alignment: .leading, spacing: 24) { // Brace 9 Open
                        // --- Profile Header Updated ---
                        HStack(alignment: .center, spacing: 16) { // Brace 10 Open
                            // Use AsyncImage for Avatar
                            AsyncImage(url: URL(string: profile.avatarUrl ?? "")) { phase in
                                switch phase {
                                case .empty:
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable().foregroundColor(.gray)
                                        .overlay(ProgressView().scaleEffect(0.8)) // Small progress
                                case .success(let image):
                                    image.resizable()
                                case .failure:
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable().foregroundColor(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .aspectRatio(contentMode: .fill) // Changed to fill
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1)) // Subtle border

                            VStack(alignment: .leading, spacing: 4) { // Brace 11 Open
                                Text(profile.fullName ?? "No Name") // Use fetched name
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text("@\(profile.username ?? "no_username")") // Use fetched username
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                // TODO: Calculate Average Rating later
                                Text("No rating yet") // Placeholder rating
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } // Brace 11 Close

                            Spacer() // Push Edit Profile button to the right

                            NavigationLink(destination: EditProfileView(onProfileUpdated: {
                                // Refresh profile data when EditProfileView updates it
                                Task { await loadProfileData() }
                            })) {
                                Text("Edit Profile")
                                    .font(.subheadline) // Make button less prominent
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .overlay(Capsule().stroke(Color.blue, lineWidth: 1))
                            }
                        } // Brace 10 Close
                        .padding(.horizontal)
                        // --- End Profile Header Update ---

                        // Requests Section Header
                        HStack { // Brace 12 Open
                            Text("My Requests") // Changed title
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                            // Only show "See All" if there are requests
                            if !userRequests.isEmpty { // Brace 13 Open
                                NavigationLink(destination: AllHelpRequestsView(helpRequests: userRequests)) {
                                    Text("See All")
                                        .foregroundColor(.blue)
                                }
                            } // Brace 13 Close
                        } // Brace 12 Close
                        .padding(.horizontal)

                        // Horizontally scrolling Requests - Use fetched data
                        if userRequests.isEmpty { // Brace 14 Open
                            Text("You haven't posted any requests yet.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                        } else { // Brace 14 Close, Brace 15 Open
                            ScrollView(.horizontal, showsIndicators: false) { // Brace 16 Open
                                HStack(spacing: 16) { // Brace 17 Open
                                    // Sort by creation date descending
                                    ForEach(userRequests.sorted { $0.createdAt > $1.createdAt }) { req in // Brace 18 Open
                                        // Link to RequestDetailView
                                        NavigationLink(destination: RequestDetailView(request: req)) {
                                            RequestCardView(request: req)
                                        }
                                        .buttonStyle(PlainButtonStyle()) // Use plain style for the link
                                    } // Brace 18 Close
                                } // Brace 17 Close
                                .padding(.horizontal)
                            } // Brace 16 Close
                        } // Brace 15 Close

                        // Reviews Section Header
                        HStack { // Brace 19 Open
                            Text("Reviews")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                            // Only show "See All" if there are reviews
                            if !reviews.isEmpty { // Brace 20 Open
                                NavigationLink(destination: AllReviewsView(reviews: reviews)) {
                                    Text("See All")
                                        .foregroundColor(.blue)
                                }
                            } // Brace 20 Close
                        } // Brace 19 Close
                        .padding(.horizontal)

                        // Horizontally scrolling Reviews
                        if isLoadingReviews { // Show loader while reviews are loading
                            ProgressView().padding(.horizontal)
                        } else if let reviewsError { // Show error if loading failed
                            Text("Error loading reviews: \(reviewsError)")
                                .font(.caption).foregroundColor(.red).padding(.horizontal)
                        } else if reviews.isEmpty { // Brace 21 Open
                            Text("You haven't received any reviews yet.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                        } else { // Brace 21 Close, Brace 22 Open
                            ScrollView(.horizontal, showsIndicators: false) { // Brace 23 Open
                                HStack(spacing: 16) { // Brace 24 Open
                                    ForEach(reviews) { review in // Brace 25 Open
                                        ReviewCardView(review: review)
                                    } // Brace 25 Close
                                } // Brace 24 Close
                                .padding(.horizontal)
                            } // Brace 23 Close
                        } // Brace 22 Close

                    } // Brace 9 Close
                    .padding(.vertical)
                } // Brace 8 Close
            } else { // Brace 7 Close
                // Fallback if profile is somehow nil after loading without error
                Text("Could not load profile.")
                    .frame(maxHeight: .infinity)
            }
        } // Brace 3 Close
        .navigationTitle("Profile") // Set title here
        .navigationBarTitleDisplayMode(.inline)
        .task { // Fetch data when view appears
            await loadProfileData()
            await loadReviews() // Call the Review task
        } // Brace 26
    } // Brace 2 Close

    // Function to load profile and requests
    @MainActor
    func loadProfileData() async { // Brace 27 Open
        isLoading = true; errorMessage = nil
        do { // Brace 28 Open
            let userId = try await supabase.auth.session.user.id
            async let profileFetch: Profile = supabase.from("profiles").select().eq("id", value: userId).single().execute().value
            async let requestsFetch: [RequestData] = supabase.from("requests").select().eq("user_id", value: userId).order("created_at", ascending: false).execute().value
            let (profileResult, requestsResult) = try await (profileFetch, requestsFetch)
            self.userProfile = profileResult; self.userRequests = requestsResult
            print("Fetched profile for \(profileResult.username ?? "user") and \(requestsResult.count) requests.")
        } catch { // Brace 28 Close, Brace 29 Open
            print("❌ Error loading profile data: \(error)"); self.errorMessage = error.localizedDescription; self.userProfile = nil; self.userRequests = []
        } // Brace 29 Close
        isLoading = false
    } // Brace 27 Close

    //Reviews Data Call
    // Inside ProfileView.swift

    // **** REPLACE THIS ENTIRE FUNCTION ****
    @MainActor
    func loadReviews() async {

        guard !isLoadingReviews else {
            print("Skipping review fetch: Already loading reviews.")
                return
        }

        isLoadingReviews = true
        reviewsError = nil
        print("➡️ loadReviews: Starting fetch...") // Log start

        do {
            // 1. Get the current user's ID
            let userId = try await supabase.auth.session.user.id
            print("➡️ loadReviews: Fetching reviews for user ID: \(userId)")

            // 2. Define the struct to decode the joined data
            //    This needs to match the structure returned by the SELECT query
            struct ReviewWithReviewer: Decodable, Identifiable {
                let id: UUID
                let chatId: Int
                let requestId: Int?
                let reviewerId: UUID // Matches 'reviewerid' column
                let revieweeId: UUID // Matches 'revieweeid' column
                let rating: Int
                let description: String? // Matches 'description' column
                let createdAt: Date
                // Nested struct to hold the joined reviewer profile data
                struct ReviewerProfile: Decodable {
                    let fullName: String?
                    let avatarUrl: String?
                    enum CodingKeys: String, CodingKey {
                        case fullName = "full_name"
                        case avatarUrl = "avatar_url"
                    }
                }
                let reviewer: ReviewerProfile? // Matches the alias 'reviewer' in SELECT

                enum CodingKeys: String, CodingKey {
                    case id
                    case chatId = "chat_id"
                    case requestId = "request_id"
                    case reviewerId = "reviewerid"
                    case revieweeId = "revieweeid"
                    case rating
                    case description
                    case createdAt = "created_at"
                    case reviewer // Matches the alias 'reviewer' used in SELECT
                }
            }

            // 3. Perform the query joining reviews and profiles
            print("➡️ loadReviews: Executing query to fetch reviews with reviewer profiles...")
            let fetchedReviewsWithProfile: [ReviewWithReviewer] = try await supabase.from("reviews")
                .select("""
                    id,
                    chat_id,
                    request_id,
                    reviewerid,
                    revieweeid,
                    rating,
                    description,
                    created_at,
                    reviewer:reviewerid ( full_name, avatar_url )
                """) // Select review fields and join profile data for reviewerid aliased as 'reviewer'
                .eq("revieweeid", value: userId) // Filter for reviews ABOUT the current user
                .order("created_at", ascending: false) // Show newest reviews first
                .execute()
                .value

            print("➡️ loadReviews: Query returned \(fetchedReviewsWithProfile.count) raw review records.")

            // 4. Map the fetched data to the Review model used by the UI
            self.reviews = fetchedReviewsWithProfile.map { fetchedReview -> Review in
                // Create the Review object, populating reviewerName/ImageUrl from the joined data
                return Review(
                    id: fetchedReview.id,
                    chatId: fetchedReview.chatId,
                    requestId: fetchedReview.requestId,
                    reviewerId: fetchedReview.reviewerId,
                    revieweeId: fetchedReview.revieweeId,
                    rating: fetchedReview.rating,
                    description: fetchedReview.description,
                    createdAt: fetchedReview.createdAt,
                    // Populate from the nested 'reviewer' data
                    reviewerName: fetchedReview.reviewer?.fullName,
                    reviewerImageUrl: fetchedReview.reviewer?.avatarUrl
                )
            }

            print("✅ loadReviews: Successfully processed \(self.reviews.count) reviews.")

        } catch {
            print("❌ loadReviews: Error fetching reviews - \(error)")
            // Provide more context if it's a decoding error
            if let decodingError = error as? DecodingError {
                print("--> Decoding Error Details: \(decodingError)")
                reviewsError = "Failed to process review data. (\(error.localizedDescription))"
            } else {
                reviewsError = "Failed to load reviews: \(error.localizedDescription)"
            }
             self.reviews = [] // Clear reviews on error
        }

        isLoadingReviews = false
        print("➡️ loadReviews: Finished.")
    }
    // **** END REPLACEMENT FUNCTION ****

} // Brace 1 Close

#Preview {
    NavigationView {
        ProfileView()
    }
}
