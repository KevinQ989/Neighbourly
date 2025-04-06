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
    @StateObject private var locationManager = LocationManager.shared
    @State private var nearbyRequests: [RequestData] = []
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
                let descriptionMatch = request.description?.lowercased().contains(
                    lowercasedSearch
                ) ?? false
                return titleMatch || descriptionMatch
            }
        }
    }
    // --- End Filtered Requests ---

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // --- Uncommented and Enabled Search Bar ---
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField(
                        "Search Requests (Title, Description)",
                        text: $searchText
                    ) // Updated placeholder
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

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Categories section
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Categories")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Spacer()
                                // TODO: Link to a view showing all categories
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.blue)
                            }
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
                                            NavigationLink(
                                                destination: CategoryDetailView(
                                                    category: category,
                                                    requests: nearbyRequests
                                                )
                                            ) {
                                                CategoryView(category: category)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.bottom, 5)
                                }
                            }
                        }

                        // --- Nearby Requests section (Uses filteredRequests) ---
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Nearby Requests")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Spacer()
                                // TODO: Link to a view showing all requests
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal)

                            // Handle loading/error/empty/list states
                            if isLoadingRequests {
                                ProgressView()
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            } else if let requestError {
                                Text("Error loading requests: \(requestError)")
                                    .foregroundColor(.red)
                                    .padding()
                            } else if filteredRequests.isEmpty {
                                Text(searchText.isEmpty ?
                                    "No nearby requests found." :
                                    "No requests match your search.")
                                .foregroundColor(.gray)
                                .padding()
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 15) {
                                        // Iterate over filteredRequests
                                        ForEach(filteredRequests) { request in
                                            NavigationLink(
                                                destination: RequestDetailView(request: request)
                                            ) {
                                                RequestCard(request: request)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        // --- End Nearby Requests Section ---

                        // Map section
                        VStack(alignment: .leading) {
                            HStack { // Add HStack for title and location button
                                Text("Map")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Spacer()
                                Button {
                                    centerMapOnUserLocation()
                                } label: {
                                    Image(systemName: "location.fill")
                                }
                                .disabled(locationManager.userLocation == nil) // Disable if no location
                            }
                            .padding(.horizontal)

                            if !locationManager.isAuthorized &&
                                locationManager.authorizationStatus != .notDetermined
                            {
                                Text("Location access denied. Enable in Settings to see nearby " +
                                    "requests on map.")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.horizontal)
                            }

                            // --- Map View Updated ---
                            // Use the filtered 'requestsWithCoordinates' for annotations
                            Map(
                                coordinateRegion: $region,
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
                            .onTapGesture {
                                withAnimation {
                                    isMapFullScreen = true
                                }
                            }
                        } // Brace 21 Close (End Map Section VStack)
                    } // Brace 4 Close (End Main Content VStack)
                    .padding(.vertical)
                } // Brace 3 Close (End ScrollView)
            } // Brace 2 Close (End Outer VStack)
            .blur(radius: isMapFullScreen ? 10 : 0)
            .disabled(isMapFullScreen)

            // Full Screen Map Overlay
            if isMapFullScreen {
                FullScreenMapView(nearbyRequests: $nearbyRequests,
                                  locationManager: locationManager,
                                  isMapFullScreen: $isMapFullScreen)
                    .transition(.move(edge: .bottom))
                    .zIndex(10)
            }

        } // End ZStack
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
    func centerMapOnUserLocation() {
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
    }

    @MainActor
    func fetchCategories() async {
        isLoadingCategories = true
        categoryError = nil

        do {
            let fetchedCategories: [Category] = try await supabase.fetchCategories()

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
    func fetchNearbyRequests() async {
        guard let userCoords = locationManager.userLocation else {
            print("Skipping request fetch: User location not available.")
            // Clear requests if location becomes unavailable?
            // self.nearbyRequests = []
            // self.requestError = "Enable location services to find nearby requests."
            return
        }

        isLoadingRequests = true
        requestError = nil

        print("Fetching requests near Lat: \(userCoords.latitude), Lon: \(userCoords.longitude) within \(searchRadiusMeters)m")

        do {
            let fetchedData: [RequestData] = try await supabase.fetchNearbyRequests(
                userCoords: userCoords,
                searchRadiusMeters: searchRadiusMeters
            )

            self.nearbyRequests = fetchedData
            print("Fetched \(fetchedData.count) nearby requests via RPC.")

        } catch {
            print("❌ Error fetching nearby requests via RPC: \(error)")
            self.requestError = error.localizedDescription
        }

        isLoadingRequests = false
    }
    // --- End Updated Function ---
} // End HomePageView struct

// MARK: - Supporting Views (CategoryDetailView, CategoryView, FullScreenMapView)

// Category Detail View - Updated to use RequestData
struct CategoryDetailView: View {
    let category: Category
    let requests: [RequestData]

    // Filtered requests for the specific category
    var categoryRequests: [RequestData] {
        requests.filter { $0.category == category.categoryname }
    }

    let columns: [GridItem] = [
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        VStack {
            // Header remains the same
            HStack {
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
                            .foregroundColor(category.swiftUIColor.opacity(0.1))
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 50, height: 50)
                .padding(10)
                
                Text(category.categoryname)
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .background(category.swiftUIColor.opacity(0.1))

            // List of requests for this category
            if categoryRequests.isEmpty {
                Spacer()
                Text("No requests in this category")
                    .foregroundColor(.gray)
                Spacer()
            } else {
                ScrollView {  //Wrap LazyVGrid inside ScrollView
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(categoryRequests) { request in
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
                        .foregroundColor(category.swiftUIColor.opacity(0.1))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 50, height: 50)
            .padding(10)

            Text(category.categoryname)
                .font(.caption)
                .multilineTextAlignment(.center)
        } // Brace 39 Close
        .frame(width: 80)
    } // Brace 38 Close
} // Brace 37 Close

// FullScreenMapView (Original code included)
struct FullScreenMapView: View {
    @Binding var nearbyRequests: [RequestData]
    @Binding var isMapFullScreen: Bool
    @ObservedObject var locationManager: LocationManager
    @State private var region: MKCoordinateRegion
    @State private var selectedRequest: RequestData?
    @State private var requestAnnotations: [RequestAnnotation] = []

    init(nearbyRequests: Binding<[RequestData]>,
         locationManager: LocationManager,
         isMapFullScreen: Binding<Bool>) {
        self._nearbyRequests = nearbyRequests
        self.locationManager = locationManager
        self._isMapFullScreen = isMapFullScreen
        _region = State(initialValue: MKCoordinateRegion(
            center: locationManager.userLocation ?? CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }

    var body: some View {
        NavigationStack {
            Map(coordinateRegion: $region, annotationItems: requestAnnotations) {
                annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    Button {
                        selectedRequest = annotation.request
                    } label: {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title)
                    }
                }
            }
            .sheet(item: $selectedRequest) { request in
                RequestDetailView(request: request)
            }
            .onAppear {
                updateAnnotations()
            }
            .onChange(of: nearbyRequests) { _ in
                updateAnnotations()
            }
            .onChange(of: locationManager.equatableUserLocation) { newLocation in
                if let newCoordinate = newLocation.coordinate { //Unwrap here
                    region.center = newCoordinate
                }
            }
            .navigationTitle("Map")  //Optional title
            .navigationBarTitleDisplayMode(.inline) // Ensure title displays correctly in sheet
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation{
                            isMapFullScreen = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
        }
        .transition(.move(edge: .bottom))
    }

    func updateAnnotations() {
        requestAnnotations = nearbyRequests.map { request in
            RequestAnnotation(
                coordinate: CLLocationCoordinate2D(
                    latitude: request.latitude ?? 0.0,
                    longitude: request.longitude ?? 0.0
                ),
                title: request.title,
                subtitle: request.description,
                request: request
            )
        }
    }
}

// MARK: - Preview
#Preview { // Brace 48 Open
    HomeContentView()
}
