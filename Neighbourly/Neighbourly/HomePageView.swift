// HomePageView.swift

import SwiftUI
import MapKit // Import MapKit
import Supabase
import CoreLocation // <-- Import CoreLocation

// MARK: - Equatable Coordinate Wrapper
struct EquatableCoordinate: Equatable {
    let coordinate: CLLocationCoordinate2D?

    static func == (lhs: EquatableCoordinate, rhs: EquatableCoordinate) -> Bool {
        if lhs.coordinate == nil && rhs.coordinate == nil { return true }
        guard let lhsCoord = lhs.coordinate, let rhsCoord = rhs.coordinate else { return false }
        // Consider adding a tolerance if exact equality is too sensitive
        return lhsCoord.latitude == rhsCoord.latitude && lhsCoord.longitude == rhsCoord.longitude
    }
}

// MARK: - Category Struct
struct Category: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String
    let color: Color

    init(name: String, imageName: String) {
        self.name = name
        self.imageName = imageName
        // Assign colors based on category name
        switch name {
        case "Moving Help": self.color = .blue
        case "Tech": self.color = .green
        case "Groceries": self.color = .orange
        case "Pet Care": self.color = .purple
        case "Home Repair": self.color = .red
        default: self.color = .gray
        }
    }
}

// MARK: - Request Card View
struct RequestCard: View {
    // Use RequestData model from Models.swift
    let request: RequestData

    var body: some View {
        VStack(alignment: .leading) {
            // --- Use AsyncImage ---
            AsyncImage(url: URL(string: request.imageUrl ?? "")) { phase in
                switch phase {
                case .empty:
                    // Placeholder while loading or if URL is invalid/nil
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 140, height: 140)
                        .overlay(ProgressView()) // Show loading indicator
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill) // Fill the frame
                        .frame(width: 140, height: 140) // Fixed frame
                case .failure:
                    // Placeholder on failure
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 140, height: 140)
                        .overlay(Image(systemName: "photo").font(.largeTitle).foregroundColor(.gray))
                @unknown default:
                    EmptyView()
                }
            }
            // --- End AsyncImage ---
            .frame(width: 140, height: 140) // Apply frame to AsyncImage container

            // Basic details from RequestData
            Text(request.title) // Use title from RequestData
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(request.description ?? "No description") // Use description
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            // We need user info - fetch later or show User ID for now
            // Text("User ID: \(request.userId.uuidString.prefix(8))...")
            //    .font(.caption2)
            //    .foregroundColor(.gray)
        }
        .frame(width: 140)
        .cornerRadius(10) // Apply corner radius to the VStack
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .clipped() // Clip contents like image to the corner radius
    }
}

// MARK: - RPC Parameter Struct
struct NearbyRequestsParams: Encodable {
    let user_lon: Double
    let user_lat: Double
    let distance_meters: Double
}

// MARK: - Home Page View
struct HomePageView: View {
    // State Variables
    @State private var searchText = ""
    @State private var isMapFullScreen = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198), // Default: Singapore
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var hasCenteredMapOnUser = false
    @StateObject private var locationManager = LocationManager.shared // Use singleton or LocationManager()
    @State private var nearbyRequests: [RequestData] = []
    @State private var isLoadingRequests = false
    @State private var requestError: String?

    // Sample Categories (keep for now, fetch later if needed)
    let categories = [
        Category(name: "Moving Help", imageName: "moving_help"),
        Category(name: "Tech", imageName: "tech"),
        Category(name: "Groceries", imageName: "groceries"),
        Category(name: "Pet Care", imageName: "pet_care"),
        Category(name: "Home Repair", imageName: "home_repair")
    ]

    // Computed property for the equatable coordinate ID
    private var equatableUserLocation: EquatableCoordinate {
        EquatableCoordinate(coordinate: locationManager.userLocation)
    }

    // Define search radius in meters (e.g., 5km)
    private let searchRadiusMeters: Double = 5000.0

    // Computed property to filter requests for map annotations
    private var requestsWithCoordinates: [RequestData] {
        nearbyRequests.filter { $0.coordinate != nil }
    }

    var body: some View {
        ZStack { // Brace 1 Open
            VStack(spacing: 0) { // Brace 2 Open
                // Search bar (Original commented out code included)
                 HStack {
                     Image(systemName: "magnifyingglass")
                         .foregroundColor(.gray)

                     TextField("Search", text: $searchText)
                         .font(.system(size: 17))
                 }
                 .padding(10)
                 .background(Color(UIColor.systemGray6))
                 .cornerRadius(10)
                 .padding(.horizontal)


                ScrollView { // Brace 3 Open
                    VStack(alignment: .leading, spacing: 20) { // Brace 4 Open

                        // Categories section
                        VStack(alignment: .leading) { // Brace 5 Open
                            HStack { // Brace 6 Open
                                Text("Categories")
                                    .font(.headline).fontWeight(.bold)
                                Spacer()
                                // TODO: Link to a view showing all categories
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.blue)
                            } // Brace 6 Close
                            .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) { // Brace 7 Open
                                HStack(spacing: 20) { // Brace 8 Open
                                    ForEach(categories) { category in // Brace 9 Open
                                        // Update NavigationLink destination later if needed
                                        NavigationLink(destination: CategoryDetailView(category: category, requests: nearbyRequests)) { // Brace 10 Open
                                            CategoryView(category: category)
                                        } // Brace 10 Close
                                    } // Brace 9 Close
                                } // Brace 8 Close
                                .padding(.horizontal)
                                .padding(.bottom, 5)
                            } // Brace 7 Close
                        } // Brace 5 Close

                        // Nearby Requests section
                        VStack(alignment: .leading) { // Brace 11 Open
                            HStack { // Brace 12 Open
                                Text("Nearby Requests")
                                    .font(.headline).fontWeight(.bold)
                                Spacer()
                                // TODO: Link to a view showing all requests
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.blue)
                            } // Brace 12 Close
                            .padding(.horizontal)

                            // Handle loading and error states
                            if isLoadingRequests { // Brace 13 Open
                                ProgressView()
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            } else if let requestError { // Brace 13 Close, Brace 14 Open
                                Text("Error loading requests: \(requestError)")
                                    .foregroundColor(.red)
                                    .padding()
                            } else if nearbyRequests.isEmpty { // Brace 14 Close, Brace 15 Open
                                Text("No nearby requests found.")
                                    .foregroundColor(.gray)
                                    .padding()
                            } else { // Brace 15 Close, Brace 16 Open
                                ScrollView(.horizontal, showsIndicators: false) { // Brace 17 Open
                                    HStack(spacing: 15) { // Brace 18 Open
                                        // Use fetched nearbyRequests (RequestData)
                                        ForEach(nearbyRequests) { request in // Brace 19 Open
                                            // Wrap RequestCard in NavigationLink
                                            NavigationLink(destination: RequestDetailView(request: request)) { // Brace 20 Open
                                                RequestCard(request: request)
                                            } // Brace 20 Close
                                            .buttonStyle(PlainButtonStyle()) // Prevent card from looking like a default button
                                        } // Brace 19 Close
                                    } // Brace 18 Close
                                    .padding(.horizontal)
                                } // Brace 17 Close
                            } // Brace 16 Close
                        } // Brace 11 Close

                        // Map section - Updated
                        VStack(alignment: .leading) { // Brace 21 Open
                            HStack { // Add HStack for title and location button
                                Text("Map")
                                    .font(.headline).fontWeight(.bold)
                                Spacer()
                                Button {
                                    centerMapOnUserLocation()
                                } label: {
                                    Image(systemName: "location.fill")
                                }
                                .disabled(locationManager.userLocation == nil) // Disable if no location
                            }
                            .padding(.horizontal)

                            if !locationManager.isAuthorized && locationManager.authorizationStatus != .notDetermined {
                                Text("Location access denied. Enable in Settings to see nearby requests on map.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal)
                            }

                            // --- Map View Updated ---
                            // Use the filtered 'requestsWithCoordinates' for annotations
                            Map(coordinateRegion: $region,
                                showsUserLocation: locationManager.isAuthorized,
                                annotationItems: requestsWithCoordinates // <-- Use filtered list
                            ) { request in // Now 'request' is guaranteed to have a coordinate
                                // Force-unwrap is safe here because we filtered the list
                                MapMarker(coordinate: request.coordinate!, tint: .blue)
                            }
                            // --- End Map View Update ---
                            .frame(height: 300)
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .onTapGesture { // Brace 22 Open
                                withAnimation { // Brace 23 Open
                                    isMapFullScreen = true
                                } // Brace 23 Close
                            } // Brace 22 Close
                        } // Brace 21 Close (End Map Section VStack)
                    } // Brace 4 Close (End Main Content VStack)
                    .padding(.vertical)
                } // Brace 3 Close (End ScrollView)
            } // Brace 2 Close (End Outer VStack)
            .blur(radius: isMapFullScreen ? 10 : 0)
            .disabled(isMapFullScreen)

            // Full Screen Map Overlay (Original code included)
            if isMapFullScreen { // Brace 24 Open
                FullScreenMapView(region: $region, isFullScreen: $isMapFullScreen)
                    .transition(.move(edge: .bottom))
                    .zIndex(10)
            } // Brace 24 Close

        } // Brace 1 Close (End ZStack)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { // Request permission and start updates when view appears
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            }
            // Start updates if already authorized or when authorization changes
            locationManager.startUpdatingLocation()
        }
        .task(id: equatableUserLocation) { // React to location changes
            // Center map once when location first becomes available
            if !hasCenteredMapOnUser && locationManager.userLocation != nil {
                centerMapOnUserLocation()
            }
            // Fetch requests whenever location changes (id changes)
            if locationManager.userLocation != nil {
                 await fetchNearbyRequests() // Call the updated function
            }
        }
    } // End body

    // Function to center the map on the user's current location
    func centerMapOnUserLocation() { // Brace 25 Open
        if let userCoords = locationManager.userLocation {
            print("Centering map on user location: \(userCoords)")
            withAnimation {
                region.center = userCoords
                // Optionally adjust span if needed
                // region.span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            }
            hasCenteredMapOnUser = true // Mark that we've centered it
        } else {
            print("Cannot center map, user location not available.")
            // Optionally prompt user to enable location services
        }
    } // Brace 25 Close

    // --- Updated Function to Fetch Nearby Requests using RPC ---
    @MainActor
    func fetchNearbyRequests() async { // Brace 26 Open
        guard let userCoords = locationManager.userLocation else {
            print("Skipping request fetch: User location not available.")
            // Clear requests if location becomes unavailable?
            // self.nearbyRequests = []
            // self.requestError = "Enable location services to find nearby requests."
            return
        }

        isLoadingRequests = true
        requestError = nil
        // nearbyRequests = [] // Decide whether to clear or update

        print("Fetching requests near Lat: \(userCoords.latitude), Lon: \(userCoords.longitude) within \(searchRadiusMeters)m")

        // --- Use Encodable struct for parameters ---
        let params = NearbyRequestsParams(
            user_lon: userCoords.longitude,
            user_lat: userCoords.latitude,
            distance_meters: searchRadiusMeters
        )
        // --- End parameter update ---

        do { // Brace 27 Open
            // Call the RPC function using the Encodable struct
            let fetchedData: [RequestData] = try await supabase
                .rpc("nearby_requests", params: params) // Pass the struct directly
                .execute()
                .value

            self.nearbyRequests = fetchedData
            print("Fetched \(fetchedData.count) nearby requests via RPC.")

        } catch { // Brace 27 Close, Brace 28 Open
            print("❌ Error fetching nearby requests via RPC: \(error)")
            self.requestError = error.localizedDescription
            // Clear requests on error?
            // self.nearbyRequests = []
        } // Brace 28 Close

        isLoadingRequests = false
    } // Brace 26 Close
    // --- End Updated Function ---

} // End HomePageView struct

// MARK: - Supporting Views (CategoryDetailView, CategoryView, FullScreenMapView)

// Category Detail View - Updated to use RequestData
struct CategoryDetailView: View { // Brace 29 Open
    let category: Category
    // Accept RequestData array
    let requests: [RequestData]

    // Filtered requests for the specific category
    var categoryRequests: [RequestData] { // Brace 30 Open
        requests.filter { $0.category == category.name }
    } // Brace 30 Close

    var body: some View { // Brace 31 Open
        VStack { // Brace 32 Open
            // Header remains the same
            HStack { // Brace 33 Open
                // Use placeholder for category image if needed
                Image(systemName: "tag.fill") // Placeholder
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(category.color)
                    // .clipShape(Circle()) // Keep if using actual images

                Text(category.name)
                    .font(.title).fontWeight(.bold)
                Spacer()
            } // Brace 33 Close
            .padding()
            .background(category.color.opacity(0.1))

            // List of requests for this category
            if categoryRequests.isEmpty { // Brace 34 Open
                Spacer()
                Text("No requests in this category")
                    .foregroundColor(.gray)
                Spacer()
            } else { // Brace 34 Close, Brace 35 Open
                List(categoryRequests) { request in // Brace 36 Open
                    // Use RequestCard or a custom row for this list
                    RequestCard(request: request) // Example: Reuse RequestCard
                        .padding(.vertical, 4)
                } // Brace 36 Close
            } // Brace 35 Close
        } // Brace 32 Close
        // Remove redundant navigation title if using the one from NavigationLink
        // .navigationTitle(category.name)
        // Ensure back button is shown (should be default)
        // .navigationBarBackButtonHidden(false)
    } // Brace 31 Close
} // Brace 29 Close

// Updated CategoryView to use color (remains the same)
struct CategoryView: View { // Brace 37 Open
    let category: Category
    var body: some View { // Brace 38 Open
        VStack { // Brace 39 Open
            // Use placeholder if needed
            Image(systemName: "tag") // Placeholder
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .padding(10)
                .background(category.color.opacity(0.2))
                .foregroundColor(category.color)
                .clipShape(Circle())
                // .overlay(Circle().stroke(category.color.opacity(0.2), lineWidth: 1))

            Text(category.name)
                .font(.caption)
                .multilineTextAlignment(.center)
        } // Brace 39 Close
        .frame(width: 80)
    } // Brace 38 Close
} // Brace 37 Close

// FullScreenMapView (Original code included)
struct FullScreenMapView: View { // Brace 40 Open
    @Binding var region: MKCoordinateRegion
    @Binding var isFullScreen: Bool
    @State private var fixedRegion: MKCoordinateRegion

    init(region: Binding<MKCoordinateRegion>, isFullScreen: Binding<Bool>) { // Brace 41 Open
        self._region = region
        self._isFullScreen = isFullScreen
        self._fixedRegion = State(initialValue: region.wrappedValue)
    } // Brace 41 Close

    var body: some View { // Brace 42 Open
        ZStack(alignment: .topLeading) { // Brace 43 Open
            Map(coordinateRegion: $fixedRegion,
                interactionModes: .all,
                showsUserLocation: true)
                .edgesIgnoringSafeArea(.all)
                .gesture(
                    DragGesture()
                        .onEnded { _ in // Brace 44 Open
                            // Limit the span to prevent excessive zooming
                            fixedRegion.span.latitudeDelta = min(max(fixedRegion.span.latitudeDelta, 0.005), 0.1)
                            fixedRegion.span.longitudeDelta = min(max(fixedRegion.span.longitudeDelta, 0.005), 0.1)

                            // Update the original region for persistence
                            region = fixedRegion
                        } // Brace 44 Close
                )

            // Back Button
            Button { // Brace 45 Open
                withAnimation { // Brace 46 Open
                    isFullScreen = false
                } // Brace 46 Close
            } label: { // Brace 45 Close
                HStack { // Brace 47 Open
                    Image(systemName: "chevron.left")
                    Text("Back")
                } // Brace 47 Close
                .padding()
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
                .padding()
            }
        } // Brace 43 Close
    } // Brace 42 Close
} // Brace 40 Close

// MARK: - Preview
#Preview { // Brace 48 Open
    // Wrap HomePageView in a structure that provides navigation context if needed
    TabView { // Brace 49 Open
        NavigationView { // Add NavigationView for preview context
             HomePageView()
        }
            .tabItem { Label("Home", systemImage: "house") }
    } // Brace 49 Close
} // Brace 48 Close
