import SwiftUI

// MARK: - Models

struct HelpRequest: Identifiable {
  let id = UUID()
  let title: String
  let description: String
  let date: Date
  let imageName: String  // <-- Insert your help request image asset name here.
}

struct Review: Identifiable {
  let id = UUID()
  let reviewerName: String
  let reviewerImageName: String  // <-- Insert your reviewer's profile image asset name here.
  let reviewText: String
  let rating: Int // rating from 0 to 5
}

let dateFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .medium
  return formatter
}()

// MARK: - Card Views

struct RequestCardView: View {
  let request: HelpRequest
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Request photo
      Image(request.imageName)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(height: 150)
        .clipped()
      
      // Request details
      VStack(alignment: .leading, spacing: 8) {
        Text(request.title)
          .font(.headline)
          .fontWeight(.semibold)
        Text(request.description)
          .font(.body)
          .lineLimit(2)
          .foregroundColor(.secondary)
        Text(dateFormatter.string(from: request.date))
          .font(.caption)
          .foregroundColor(.gray)
      }
      .padding()
    }
    .frame(width: 250, alignment: .leading)
    .background(Color(.systemGray6))
    .cornerRadius(10)
    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
  }
}

/* Updated ReviewCardView:
   - Reviewer name is on its own line.
   - The rating is shown on a separate line below the name.
 */
struct ReviewCardView: View {
  let review: Review
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top) {
        // Reviewer profile image
          Image(review.reviewerImageName)
                  .resizable()
                  .aspectRatio(contentMode: .fill)
                  .frame(width: 40, height: 40)
                  .clipShape(Circle())
                  .padding(.trailing, 8)
        
        // Use a vertical stack for the reviewer details
        VStack(alignment: .leading, spacing: 4) {
          Text(review.reviewerName)
            .font(.headline)
            .fontWeight(.bold)
          // Rating displayed on a new line
          HStack(spacing: 2) {
            ForEach(0..<5) { index in
              Image(systemName: index < review.rating ? "star.fill" : "star")
                .foregroundColor(index < review.rating ? .yellow : .gray)
            }
          }
          Text(review.reviewText)
            .font(.body)
            .lineLimit(2)
            .foregroundColor(.secondary)
        }
      }
    }
    .padding()
    .frame(width: 250, alignment: .leading)
    .background(Color(.systemGray6))
    .cornerRadius(10)
    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
  }
}

// MARK: - Detailed List Views

struct AllHelpRequestsView: View {
  let helpRequests: [HelpRequest]
  
  var body: some View {
    List(helpRequests.sorted { $0.date > $1.date }, id: \.id) { req in
      VStack(alignment: .leading, spacing: 8) {
        Text(req.title)
          .font(.headline)
          .fontWeight(.semibold)
        Text(req.description)
          .font(.body)
          .foregroundColor(.secondary)
        Text(dateFormatter.string(from: req.date))
          .font(.caption)
          .foregroundColor(.gray)
      }
      .padding(.vertical, 4)
    }
    .navigationTitle("All Requests")
  }
}

/* Updated AllReviewsView:
   The reviewer's name is shown on the top line, with the rating below it.
 */
struct AllReviewsView: View {
  let reviews: [Review]
  
  var body: some View {
    List(reviews, id: \.id) { review in
      HStack(alignment: .top, spacing: 8) {
        Image(review.reviewerImageName)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 40, height: 40)
          .clipShape(Circle())
        VStack(alignment: .leading, spacing: 4) {
          Text(review.reviewerName)
            .fontWeight(.bold)
          HStack(spacing: 2) {
            ForEach(0..<5) { index in
              Image(systemName: index < review.rating ? "star.fill" : "star")
                .foregroundColor(index < review.rating ? .yellow : .gray)
            }
          }
          Text(review.reviewText)
            .font(.body)
            .foregroundColor(.secondary)
        }
      }
      .padding(.vertical, 4)
    }
    .navigationTitle("All Reviews")
  }
}

// MARK: - Tab Bar (Renamed from CustomTabBar)

struct TabBar: View {
  var body: some View {
    HStack {
      ForEach(["house.fill", "plus.circle.fill", "message.fill", "person.fill"],
              id: \.self) { icon in
        Spacer()
        Button(action: {
          // Handle tab selection here
        }) {
          Image(systemName: icon)
            .font(.system(size: 22))
            .foregroundColor(icon == "house.fill" ? .black : .gray)
        }
        Spacer()
      }
    }
    .padding(.vertical, 10)
    .background(Color.white)
    .overlay(
      Rectangle()
        .frame(height: 1)
        .foregroundColor(Color.gray.opacity(0.2)),
      alignment: .top
    )
  }
}

// MARK: - Main Profile View

struct ProfileView: View {
  // Profile Information
  let name: String = "Mr Yap Yap"
  let username: String = "zekaistic"
  let profileImageName: String = "mr yap" // <-- Insert your profile picture asset name here.
  
  // Sample data for the requests and reviews.
  @State private var helpRequests: [HelpRequest] = [
    HelpRequest(
      title: "Need help moving furniture",
      description: "Looking for extra hands to help move my couch and bookshelf.",
      date: Date(),
      imageName: "sofa_image"  // <-- Insert your help request image asset name here.
    ),
    HelpRequest(
      title: "Gardening help",
      description: "Need assistance trimming my garden hedges.",
      date: Date().addingTimeInterval(-86400),
      imageName: "gardening"  // <-- Insert your help request image asset name here.
    )
  ]
  
  @State private var reviews: [Review] = [
    Review(
      reviewerName: "Durren Tan",
      reviewerImageName: "daren",  // <-- Insert your reviewer's image asset name here.
      reviewText: "Very kind and cooperative!",
      rating: 5
    ),
    Review(
      reviewerName: "Kelvin Quah",
      reviewerImageName: "kevin",  // <-- Insert your reviewer's image asset name here.
      reviewText: "Quick with responses. Would definitely recommend.",
      rating: 4
    )
  ]
  
  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            // Profile Header
            HStack(alignment: .center, spacing: 16) {
                Image(profileImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.title)
                        .fontWeight(.bold)
                    Text("@\(username)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    // Fixed Average Rating Display with a star emoji
                    Text("4.5/5⭐")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                NavigationLink(
                    destination: EditProfileView()
                ) {
                    Text("Edit Profile")
                        .foregroundColor(.blue)
                }
              Spacer()
            }
            .padding(.horizontal)
            
            // Requests Section Header
            HStack {
              Text("Requests")
                .font(.title2)
                .fontWeight(.semibold)
              Spacer()
              NavigationLink(
                destination: AllHelpRequestsView(helpRequests: helpRequests)
              ) {
                Text("See All")
                  .foregroundColor(.blue)
              }
            }
            .padding(.horizontal)
            
            // Horizontally scrolling Requests
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 16) {
                ForEach(helpRequests.sorted { $0.date > $1.date }) { req in
                  RequestCardView(request: req)
                }
              }
              .padding(.horizontal)
            }
            
            // Reviews Section Header
            HStack {
              Text("Reviews")
                .font(.title2)
                .fontWeight(.semibold)
              Spacer()
              NavigationLink(
                destination: AllReviewsView(reviews: reviews)
              ) {
                Text("See All")
                  .foregroundColor(.blue)
              }
            }
            .padding(.horizontal)
            
            // Horizontally scrolling Reviews
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 16) {
                ForEach(reviews) { review in
                  ReviewCardView(review: review)
                }
              }
              .padding(.horizontal)
            }
          }
          .padding(.vertical)
        }
        Divider()
        TabBar()
      }
      .navigationBarTitle("Profile", displayMode: .inline)
    }
  }
}

// MARK: - Preview

struct ProfileView_Previews: PreviewProvider {
  static var previews: some View {
    ProfileView()
  }
}
