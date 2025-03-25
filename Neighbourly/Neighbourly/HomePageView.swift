import SwiftUI
import MapKit

// Update Category struct to include a color for visual distinction
struct Category: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String
    let color: Color
    
    // Add a custom initializer to maintain backward compatibility
    init(name: String, imageName: String) {
        self.name = name
        self.imageName = imageName
        
        // Assign colors based on category name
        switch name {
        case "Moving Help":
            self.color = .blue
        case "Tech":
            self.color = .green
        case "Groceries":
            self.color = .orange
        case "Pet Care":
            self.color = .purple
        case "Home Repair":
            self.color = .red
        default:
            self.color = .gray
        }
    }
}

// Update Request struct to include a category
struct Request: Identifiable {
    let id: Int
    let userName: String
    let description: String
    let imageName: String
    let category: String
    
    // Add a custom initializer to maintain backward compatibility
    init(id: Int, userName: String, description: String, imageName: String, category: String? = nil) {
        self.id = id
        self.userName = userName
        self.description = description
        self.imageName = imageName
        
        // If no category is provided, attempt to guess based on description
        if let category = category {
            self.category = category
        } else {
            // Basic category inference
            if description.lowercased().contains("sofa") || description.lowercased().contains("move") {
                self.category = "Moving Help"
            } else if description.lowercased().contains("tech") || description.lowercased().contains("laptop") {
                self.category = "Tech"
            } else if description.lowercased().contains("cat") {
                self.category = "Pet Care"
            } else {
                self.category = "Other"
            }
        }
    }
}

// Request card
struct RequestCard: View {
    let request: Request
    
    var body: some View {
        VStack(alignment: .leading) {
            Image(request.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 140, height: 140)
                .cornerRadius(10)
                .clipped()
            
            Text(request.userName)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(request.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 140)
    }
}

struct HomePageView: View {
    @State private var searchText = ""
    @State private var isMapFullScreen = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198), // Singapore coordinates as default
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    // Sample data for categories
    let categories = [
        Category(name: "Moving Help", imageName: "moving_help"),
        Category(name: "Tech", imageName: "tech"),
        Category(name: "Groceries", imageName: "groceries"),
        Category(name: "Pet Care", imageName: "pet_care"),
        Category(name: "Home Repair", imageName: "home_repair")
    ]
    
    // Sample data for nearby requests
    let nearbyRequests = [
        Request(id: 1, userName: "Daren Tan", description: "Help me move my sofa", imageName: "sofa_image", category: "Moving Help"),
        Request(id: 2, userName: "Ng Jun Ying", description: "Take care of my cat", imageName: "cat_image", category: "Pet Care"),
        Request(id: 3, userName: "Esther K", description: "Tech support needed", imageName: "tech_support", category: "Tech")
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
//                    // Search bar
//                    HStack {
//                        Image(systemName: "magnifyingglass")
//                            .foregroundColor(.gray)
//
//                        TextField("Search", text: $searchText)
//                            .font(.system(size: 17))
//                    }
//                    .padding(10)
//                    .background(Color(UIColor.systemGray6))
//                    .cornerRadius(10)
//                    .padding(.horizontal)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Categories section
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Categories")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 20) {
                                        ForEach(categories) { category in
                                            NavigationLink(destination: CategoryDetailView(category: category, requests: nearbyRequests)) {
                                                CategoryView(category: category)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.bottom, 5)
                                }
                            }
                            
                            // Nearby Requests section
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Nearby Requests")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 15) {
                                        ForEach(nearbyRequests) { request in
                                            RequestCard(request: request)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            // Map section
                            VStack(alignment: .leading) {
                                Text("Map")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                
                                Map(coordinateRegion: $region, showsUserLocation: true)
                                    .frame(height: 300)
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                                    .onTapGesture {
                                        withAnimation {
                                            isMapFullScreen = true
                                        }
                                    }
                            }
                        }
                        .padding(.vertical)
                    }
                }
                .blur(radius: isMapFullScreen ? 10 : 0)
                .disabled(isMapFullScreen)
                
                // Full Screen Map Overlay
                if isMapFullScreen {
                    FullScreenMapView(region: $region, isFullScreen: $isMapFullScreen)
                        .transition(.move(edge: .bottom))
                        .zIndex(10)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// Category Detail View
struct CategoryDetailView: View {
    let category: Category
    let requests: [Request]
    
    // Filtered requests for the specific category
    var categoryRequests: [Request] {
        requests.filter { $0.category == category.name }
    }
    
    var body: some View {
        VStack {
            // Header with category name and icon
            HStack {
                Image(category.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                
                Text(category.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding()
            .background(category.color.opacity(0.1))
            
            // List of requests for this category
            if categoryRequests.isEmpty {
                Spacer()
                Text("No requests in this category")
                    .foregroundColor(.gray)
                Spacer()
            } else {
                List(categoryRequests) { request in
                    HStack {
                        Image(request.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading) {
                            Text(request.userName)
                                .font(.headline)
                            Text(request.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(false)
        .navigationTitle(category.name)
    }
}

// Updated CategoryView to use color
struct CategoryView: View {
    let category: Category
    
    var body: some View {
        VStack {
            Image(category.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 70, height: 70)
                .clipShape(Circle())
                .overlay(Circle().stroke(category.color.opacity(0.2), lineWidth: 1))
            
            Text(category.name)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .frame(width: 80)
    }
}

struct FullScreenMapView: View {
    @Binding var region: MKCoordinateRegion
    @Binding var isFullScreen: Bool
    
    // Create a copy of the original region to maintain zoom
    @State private var fixedRegion: MKCoordinateRegion
    
    // Initialize with the binding's current value
    init(region: Binding<MKCoordinateRegion>, isFullScreen: Binding<Bool>) {
        self._region = region
        self._isFullScreen = isFullScreen
        // Create a state copy of the initial region
        self._fixedRegion = State(initialValue: region.wrappedValue)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Map(coordinateRegion: $fixedRegion,
                interactionModes: .all,
                showsUserLocation: true)
                .edgesIgnoringSafeArea(.all)
                .gesture(
                    DragGesture()
                        .onEnded { _ in
                            // Limit the span to prevent excessive zooming
                            fixedRegion.span.latitudeDelta = min(max(fixedRegion.span.latitudeDelta, 0.005), 0.1)
                            fixedRegion.span.longitudeDelta = min(max(fixedRegion.span.longitudeDelta, 0.005), 0.1)
                            
                            // Update the original region for persistence
                            region = fixedRegion
                        }
                )
            
            // Back Button
            Button(action: {
                withAnimation {
                    isFullScreen = false
                }
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .padding()
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
                .padding()
            }
        }
    }
}

#Preview {
    HomePageView()
}
