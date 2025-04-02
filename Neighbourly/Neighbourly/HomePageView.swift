// HomePageView.swift

import SwiftUI
import MapKit
import Supabase
import CoreLocation

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

// MARK: - Request Card View
struct RequestCard: View {
    // Use RequestData model from Models.swift
    let request: RequestData

    var body: some View {
        VStack(alignment: .leading) {
            // --- Use AsyncImage ---
            AsyncImage(url: URL(string: request.imageUrl ?? "")) { phase in // Create URL from optional string
                switch phase {
                case .empty:
                    // Placeholder while loading or if URL is invalid/nil
                    ZStack { // Use ZStack to center ProgressView
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                        ProgressView()
                    }
                case .success(let image):
                    image
                        .resizable() // Make image resizable
                        .aspectRatio(contentMode: .fill) // Fill the frame
                case .failure:
                    // Placeholder on failure (e.g., bad URL, network error)
                    ZStack { // Use ZStack to center icon
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                        Image(systemName: "photo.fill") // System icon for placeholder
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.gray)
                    }
                @unknown default:
                    // Fallback for future cases
                    EmptyView()
                }
            }
            // --- End AsyncImage ---
            .frame(width: 140, height: 140) // Apply frame to AsyncImage container
            .clipped() // Clip the image content to the frame

            // Basic details from RequestData
            Text(request.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .padding(.top, 4) // Add slight padding

            Text(request.description ?? "No description")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .padding(.bottom, 4) // Add slight padding

        }
        .frame(width: 140) // Keep overall card width
        // Apply background and corner radius to the VStack for consistent look
        .background(Color(UIColor.systemGray6)) // Background for the text area too
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        // No need for .clipped() here as content is within bounds or image is clipped
    }
}
// --- End Request Card View Update ---

// MARK: - RPC Parameter Struct
struct NearbyRequestsParams: Encodable {
    let user_lon: Double
    let user_lat: Double
    let distance_meters: Double
}

struct HomeContentView: View {
    var body: some View {
        NavigationView {
            HomePageView()
        }
    }
}

// MARK: - Home Page View
struct HomePageView: View {
    // State Variables
    @State private var searchText = "" // State for the search text
    @State private var isMapFullScreen = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198), // Default: Singapore
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var hasCenteredMapOnUser = false
    @StateObject private var locationManager = LocationManager.shared // Use singleton or LocationManager()
    @State private var nearbyRequests: [RequestData] = [] // All fetched requests
    @State private var isLoadingRequests = false
    @State private var requestError: String?
    
    @State private var categories: [Category] = []
    @State private var isLoadingCategories = false
    @State private var categoryError: String?

    // Computed properties
    private var equatableUserLocation: EquatableCoordinate {
        EquatableCoordinate(coordinate: locationManager.userLocation)
    }
    private let searchRadiusMeters: Double = 5000.0
    private var requestsWithCoordinates: [RequestData] {
        nearbyRequests.filter { $0.coordinate != nil }
    }

    // --- Computed Property for Filtered Requests ---
    private var filteredRequests: [RequestData] {
        if searchText.isEmpty {
            return nearbyRequests // Return all if search is empty
        } else {
            // Filter based on title or description containing searchText (case-insensitive)
            let lowercasedSearch = searchText.lowercased()
            return nearbyRequests.filter { request in
                let titleMatch = request.title.lowercased().contains(lowercasedSearch)
                let descriptionMatch = request.description?.lowercased().contains(lowercasedSearch) ?? false
                return titleMatch || descriptionMatch
            }
        }
    }
    // --- End Filtered Requests ---

    var body: some View {
        ZStack { // Brace 1 Open
            VStack(spacing: 0) { // Brace 2 Open
                // --- Uncommented and Enabled Search Bar ---
                 HStack {
                     Image(systemName: "magnifyingglass")
                         .foregroundColor(.gray)
                     TextField("Search Requests (Title, Description)", text: $searchText) // Updated placeholder
                         .font(.system(size: 17))
                         .autocorrectionDisabled() // Disable autocorrect for search
                         .textInputAutocapitalization(.never) // Don't capitalize search input
                     // Add clear button if search text is not empty
                     if !searchText.isEmpty {
                         Button {
                             searchText = "" // Clear the search text
                         } label: {
                             Image(systemName: "xmark.circle.fill")
                                 .foregroundColor(.gray)
                         }
                     }
                 }
                 .padding(10)
                 .background(Color(UIColor.systemGray6))
                 .cornerRadius(10)
                 .padding(.horizontal)
                 .padding(.bottom, 5) // Add some padding below search bar
                 // --- End Search Bar ---

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

                            if isLoadingCategories {
                                ProgressView()
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            } else if let categoryError {
                                Text("Error loading categories: \(categoryError)")
                                    .foregroundColor(.red)
                                    .padding()
                            } else if categories.isEmpty {
                                Text("No categories available.")
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
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
                        } // Brace 5 Close

                        // --- Nearby Requests section (Uses filteredRequests) ---
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

                            // Handle loading/error/empty/list states
                            if isLoadingRequests { // Brace 13 Open
                                ProgressView()
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            } else if let requestError { // Brace 13 Close, Brace 14 Open
                                Text("Error loading requests: \(requestError)")
                                    .foregroundColor(.red)
                                    .padding()
                            } else if filteredRequests.isEmpty { // Brace 15 Open
                                Text(searchText.isEmpty ? "No nearby requests found." : "No requests match your search.") // Dynamic empty message
                                    .foregroundColor(.gray)
                                    .padding()
                            } else { // Brace 15 Close, Brace 16 Open
                                ScrollView(.horizontal, showsIndicators: false) { // Brace 17 Open
                                    HStack(spacing: 15) { // Brace 18 Open
                                        // Iterate over filteredRequests
                                        ForEach(filteredRequests) { request in // Brace 19 Open
                                            NavigationLink(destination: RequestDetailView(request: request)) { // Brace 20 Open
                                                RequestCard(request: request)
                                            } // Brace 20 Close
                                            .buttonStyle(PlainButtonStyle())
                                        } // Brace 19 Close
                                    } // Brace 18 Close
                                    .padding(.horizontal)
                                } // Brace 17 Close
                            } // Brace 16 Close
                        } // Brace 11 Close
                        // --- End Nearby Requests Section ---

                        // Map section
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

            // Full Screen Map Overlay
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
            
            Task {
                await fetchCategories()
            }
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
    
    @MainActor
    func fetchCategories() async {
        isLoadingCategories = true
        categoryError = nil
        
        do {
            let fetchedCategories: [Category] = try await supabase
                .from("categories")
                .select()
                .execute()
                .value
            
            self.categories = fetchedCategories
            print("Fetched \(fetchedCategories.count) categories.")
        } catch {
            print("❌ Error fetching categories: \(error)")
            categoryError = error.localizedDescription
        }
        
        isLoadingCategories = false
    }
    
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
        requests.filter { $0.category == category.categoryname }
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
                    .foregroundColor(Color(category.color))
                    // .clipShape(Circle()) // Keep if using actual images

                Text(category.categoryname)
                    .font(.title).fontWeight(.bold)
                Spacer()
            } // Brace 33 Close
            .padding()
            .background(Color(category.color).opacity(0.1))

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
            AsyncImage(url: URL(string: category.imageurl)) { phase in
                switch phase {
                case .empty:
                    // Show placeholder or loading indicator
                    ProgressView()
                        .frame(width: 50, height: 50)
                case .success(let image):
                    // Show the loaded image
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                case .failure:
                    // Show fallback for failed loads
                    Image(systemName: "tag.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(Color(category.color))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 50, height: 50)
            .padding(10)
            .background(Color(category.color).opacity(0.2))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color(category.color), lineWidth: 2)
            )


            Text(category.categoryname)
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
    HomeContentView()
}
