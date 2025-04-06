// ProfileView.swift

import SwiftUI
import Supabase

// MARK: - Models (Local or Shared)
// Using RequestData from Models.swift
// Using Profile from Models.swift

// Review struct remains local for now as placeholder
struct Review: Identifiable {
  let id = UUID()
  let reviewerName: String
  let reviewerImageName: String // Keep for sample data structure
  let reviewText: String
  let rating: Int
}

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

// ReviewCardView (Uses local Review struct)
struct ReviewCardView: View {
  let review: Review

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top) {
        Image(systemName: "person.crop.circle.fill").resizable().aspectRatio(contentMode: .fill).frame(width: 40, height: 40).clipShape(Circle()).foregroundColor(.gray).padding(.trailing, 8) // Placeholder
        VStack(alignment: .leading, spacing: 4) {
          Text(review.reviewerName).font(.headline).fontWeight(.bold)
          HStack(spacing: 2) { ForEach(0..<5) { index in Image(systemName: index < review.rating ? "star.fill" : "star").foregroundColor(index < review.rating ? .yellow : .gray) } }
          Text(review.reviewText).font(.body).lineLimit(2).foregroundColor(.secondary)
        }
      }
    }
    .padding().frame(width: 250, alignment: .leading).background(Color(.systemGray6)).cornerRadius(10).shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
  }
}

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

// AllReviewsView (Uses local Review struct)
struct AllReviewsView: View {
  let reviews: [Review]

  var body: some View {
    List(reviews, id: \.id) { review in
      HStack(alignment: .top, spacing: 8) {
        Image(systemName: "person.crop.circle.fill").resizable().aspectRatio(contentMode: .fill).frame(width: 40, height: 40).clipShape(Circle()).foregroundColor(.gray) // Placeholder
        VStack(alignment: .leading, spacing: 4) {
          Text(review.reviewerName).fontWeight(.bold)
          HStack(spacing: 2) { ForEach(0..<5) { index in Image(systemName: index < review.rating ? "star.fill" : "star").foregroundColor(index < review.rating ? .yellow : .gray) } }
          Text(review.reviewText).font(.body).foregroundColor(.secondary)
        }
      }
      .padding(.vertical, 4)
    }
    .navigationTitle("All Reviews")
  }
}

// MARK: - Main Profile View (Updated)

struct ProfileView: View { // Brace 1 Open
  // State for fetched data
  @State private var userProfile: Profile? = nil
  @State private var userRequests: [RequestData] = []
  @State private var isLoading = false
  @State private var errorMessage: String?

  // Sample data for reviews (placeholder)
  @State private var reviews: [Review] = [
    Review(reviewerName: "Durren Tan", reviewerImageName: "daren", reviewText: "Very kind and cooperative!", rating: 5),
    Review(reviewerName: "Kelvin Quah", reviewerImageName: "kevin", reviewText: "Quick with responses. Would definitely recommend.", rating: 4)
  ]

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


                // Reviews Section Header (Placeholder)
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

                // Horizontally scrolling Reviews (Placeholder using sample data)
                if reviews.isEmpty { // Brace 21 Open
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

} // Brace 1 Close

#Preview { NavigationView { ProfileView() } } // Brace 30, 31
