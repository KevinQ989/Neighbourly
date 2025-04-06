// NewRequestView.swift

import SwiftUI
import Supabase
import CoreLocation
import PhotosUI
import MapKit // <-- Import MapKit

// --- CLASS DEFINITION HERE (OUTSIDE THE STRUCT) ---
// This class acts as the delegate for MKLocalSearchCompleter
// and publishes the results for SwiftUI views.
class LocationSearchCompleterDelegate: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {

    @Published var completions: [MKLocalSearchCompletion] = [] // Suggestions
    @Published var error: Error? = nil // To report errors

    private var completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        // Optional: Filter results (e.g., only addresses)
        // completer.resultTypes = .address
        // Optional: Limit search region (e.g., to user's current region)
        // if let region = LocationManager.shared.userRegion { // Assuming you have a way to get region
        //     completer.region = region
        // }
    }

    // Public property to trigger searches
    var searchQuery: String = "" {
        didSet {
            error = nil // Clear previous errors
            // Prevent searching for empty string which can sometimes cause issues
            guard !searchQuery.isEmpty else {
                self.completions = []
                return
            }
            print("➡️ Completer searching for: '\(searchQuery)'") // Debug Log
            completer.queryFragment = searchQuery
        }
    }

    // MARK: - MKLocalSearchCompleterDelegate Methods

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // Filter out results without titles (can sometimes happen)
        self.completions = completer.results.filter { !$0.title.isEmpty }
        self.error = nil // Clear error on success
        print("⬅️ Completer found \(self.completions.count) results.") // Debug Log
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        self.error = error
        self.completions = [] // Clear results on error
        print("❌ Completer failed with error: \(error.localizedDescription)") // Debug Log
    }
}
// --- END CLASS DEFINITION ---

// --- PreferenceKey definition (outside the struct) ---
struct TextFieldFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero // Default value

    // Combine values if multiple views report a preference
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        // Use the frame reported by the text field
        value = nextValue()
    }
}


// --- STRUCT DEFINITION STARTS HERE ---
struct NewRequestView: View {
    // Form fields
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedCategory: String = ""
    @State private var date: Date = Date()

    // --- Location State ---
    @State private var locationQuery: String = "" // What the user types
    @StateObject private var completerDelegate = LocationSearchCompleterDelegate() // Handles suggestions
    @State private var selectedCompletion: MKLocalSearchCompletion? = nil // Store the chosen suggestion
    @State private var selectedCoordinate: CLLocationCoordinate2D? = nil // Store the final coordinate (MUST BE OPTIONAL '?')
    @State private var isSearchingCoordinates = false // Loading indicator for MKLocalSearch
    @State private var locationErrorMessage: String? = nil // Specific error for location search
    @State private var showSuggestions: Bool = false // Controls overlay visibility
    @State private var textFieldFrame: CGRect = .zero // Stores measured frame of TextField
    // --- End Location State ---

    // Image Picker State
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var selectedImagePreview: Image? = nil

    // General State
    @State private var isLoading = false // For the final posting step
    @State private var isUploading = false
    @State private var errorMessage: String? // General errors
    @State private var successMessage: String?

    let categories = ["Moving Help", "Tech", "Groceries", "Pet Care", "Home Repair", "Other"]
    let formCoordinateSpace = "formCoordinateSpace" // Name for coordinate space

    // Initialize category selection
    init() {
        _selectedCategory = State(initialValue: categories.first ?? "")
    }

    var body: some View {
        NavigationView {
            // Use GeometryReader to provide size context for fallback positioning
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    Form {
                        Section(header: Text("Request Details")) {
                            TextField("Title (Required)", text: $title)

                            VStack(alignment: .leading) {
                                Text("Description")
                                    .font(.caption).foregroundColor(.gray)
                                TextEditor(text: $description)
                                    .frame(height: 100)
                                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(UIColor.systemGray4)))
                            }

                            Picker("Category", selection: $selectedCategory) {
                                ForEach(categories, id: \.self) { category in
                                    Text(category)
                                }
                            }

                            DatePicker("Complete By", selection: $date, displayedComponents: [.date, .hourAndMinute])

                            // --- Location Input Section ---
                            VStack(alignment: .leading) {
                                Text("Location")
                                    .font(.caption).foregroundColor(.gray)

                                // Search Field - Measure its frame
                                TextField("Search address or place", text: $locationQuery)
                                    .background(
                                        GeometryReader { proxy in
                                            Color.clear
                                                .preference(
                                                    key: TextFieldFramePreferenceKey.self,
                                                    value: proxy.frame(in: .named(formCoordinateSpace))
                                                )
                                        }
                                    )
                                    .onChange(of: locationQuery) { newValue in
                                        print("✏️ locationQuery changed: '\(newValue)'") // Debug Log
                                        completerDelegate.searchQuery = newValue
                                        if selectedCompletion != nil {
                                            selectedCompletion = nil
                                            selectedCoordinate = nil
                                            locationErrorMessage = nil
                                        }
                                        // Update showSuggestions state
                                        let shouldShow = !newValue.isEmpty && !isSearchingCoordinates
                                        print("ℹ️ Setting showSuggestions to: \(shouldShow)") // Debug Log
                                        // Use animation to make state change smoother if needed
                                        withAnimation(.easeInOut(duration: 0.1)) {
                                            showSuggestions = shouldShow
                                        }
                                    }

                                // Show loading/error indicators
                                if isSearchingCoordinates {
                                    ProgressView("Getting coordinates...")
                                        .padding(.top, 5)
                                } else if let locError = locationErrorMessage {
                                    Text(locError)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding(.top, 5)
                                }
                                // Display completer error directly if suggestions are hidden but error exists
                                else if let completerError = completerDelegate.error, !showSuggestions, !locationQuery.isEmpty {
                                    Text("Search Error: \(completerError.localizedDescription)")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .padding(.top, 5)
                                }
                            } // End Location VStack
                            // --- End Location Input Section ---

                        } // End Request Details Section

                        // Image Section
                        Section(header: Text("Image (Optional)")) {
                            if let imagePreview = selectedImagePreview {
                                imagePreview
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                                    .cornerRadius(8)
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            self.selectedPhotoItem = nil
                                            self.selectedImageData = nil
                                            self.selectedImagePreview = nil
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                                .background(Circle().fill(.white.opacity(0.8)))
                                                .padding(4)
                                        }
                                    }
                            }

                            PhotosPicker(
                                selection: $selectedPhotoItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label(selectedImagePreview == nil ? "Add Image" : "Change Image", systemImage: "photo")
                            }
                            .onChange(of: selectedPhotoItem) { newItem in
                                Task {
                                    self.selectedImageData = nil
                                    self.selectedImagePreview = nil
                                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                        self.selectedImageData = data
                                        if let uiImage = UIImage(data: data) {
                                            self.selectedImagePreview = Image(uiImage: uiImage)
                                        }
                                    }
                                }
                            }
                        } // End Image Section

                        // Display messages (Success/General Error)
                        if let successMessage {
                            Section { Text(successMessage).foregroundColor(.green) }
                        }
                        if let errorMessage {
                            Section { Text(errorMessage).foregroundColor(.red) }
                        }

                        // Action Buttons Section
                        Section {
                            HStack(spacing: 20) {
                                Button("Clear Form", role: .destructive) {
                                    clearForm()
                                }
                                .disabled(isLoading || isUploading || isSearchingCoordinates)

                                Spacer()

                                Button {
                                    Task {
                                        await postRequest()
                                    }
                                } label: {
                                    if isLoading || isUploading {
                                        ProgressView()
                                            .frame(maxWidth: .infinity, alignment: .center)
                                    } else {
                                        Text("Post Request")
                                            .frame(maxWidth: .infinity, alignment: .center)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(
                                    isLoading || isUploading || isSearchingCoordinates ||
                                    title.trimmingCharacters(in: .whitespaces).isEmpty ||
                                    (!locationQuery.isEmpty && selectedCoordinate == nil)
                                )
                            }
                        } // End Action Buttons Section
                    } // End Form
                    .coordinateSpace(name: formCoordinateSpace) // Define Coordinate Space for the Form
                    .scrollDismissesKeyboard(.interactively)
                    // Listen for preference changes to update the text field frame
                    .onPreferenceChange(TextFieldFramePreferenceKey.self) { frame in
                        // Only update if the frame actually changed significantly
                        if frame != .zero && frame != self.textFieldFrame {
                             print("📏 TextField Frame Updated: \(frame)") // Debug Log
                             self.textFieldFrame = frame
                        }
                    }
                    // Add background tap gesture to dismiss suggestions overlay
                    .background(
                         Color.clear
                             .contentShape(Rectangle()) // Make the whole area tappable
                             .onTapGesture {
                                 print("🖱️ Background Tapped - Hiding suggestions & keyboard") // Debug Log
                                 showSuggestions = false
                                 hideKeyboard()
                             }
                     )

                } // End VStack containing Form
                // --- Suggestions Overlay ---
                .overlay(alignment: .topLeading) { // Align overlay to top-leading corner
                    // Show overlay only when needed
                    if showSuggestions && !completerDelegate.completions.isEmpty && !isSearchingCoordinates && selectedCompletion == nil {
                        // Use the measured frame for positioning, even if it's zero initially
                        List {
                            // Show completer error within the list as well
                            if let completerError = completerDelegate.error {
                                 Text("Search Error: \(completerError.localizedDescription)")
                                     .font(.caption)
                                     .foregroundColor(.orange)
                             }
                            ForEach(completerDelegate.completions, id: \.self) { completion in
                                Button {
                                    Task {
                                        print("👆 Suggestion Tapped: \(completion.title)") // Debug Log
                                        showSuggestions = false // Hide immediately
                                        await handleCompletionSelected(completion)
                                    }
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(completion.title).font(.subheadline)
                                        Text(completion.subtitle).font(.caption).foregroundColor(.gray)
                                    }
                                }
                                .buttonStyle(.plain) // Use plain style for buttons in List
                            }
                        }
                        .listStyle(.plain)
                        .background(.thinMaterial) // Use material background for overlay
                        .cornerRadius(8)
                        .shadow(radius: 5)
                        .frame(maxHeight: 250) // Limit overlay height
                        // Position using measured frame (defaults gracefully if frame is zero)
                        .frame(width: textFieldFrame == .zero ? geometry.size.width * 0.9 : textFieldFrame.width) // Use fallback width if frame is zero
                        .offset(
                            x: textFieldFrame == .zero ? geometry.size.width * 0.05 : textFieldFrame.minX, // Use fallback x if frame is zero
                            y: textFieldFrame == .zero ? 100 : textFieldFrame.maxY + 20 // Use fallback y if frame is zero (adjust fallback Y if needed)
                        )
                        .offset(
                                                x: textFieldFrame.minX,
                                                y: textFieldFrame.maxY - 10 // Use a noticeable padding like + 15
                                            )
                        .transition(.opacity.combined(with: .move(edge: .top))) // Add transition
                        .animation(.easeInOut(duration: 0.2), value: showSuggestions) // Animate appearance
                        .onAppear { print("✅ Overlay Appeared") } // Debug Log
                        .onDisappear { print("❌ Overlay Disappeared") } // Debug Log
                    }
                }
                // --- End Suggestions Overlay ---
            } // End GeometryReader
            .navigationTitle("New Request")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                // Clear search when view disappears
                completerDelegate.searchQuery = ""
            }
        } // End NavigationView
    } // End body

    // --- Function to handle suggestion selection ---
    @MainActor
    func handleCompletionSelected(_ completion: MKLocalSearchCompletion) async {
        locationQuery = completion.title // Keep the selected text
        selectedCompletion = completion // Store the selected item
        // showSuggestions = false // Already set to false when button tapped
        completerDelegate.completions = [] // Clear suggestions list immediately
        isSearchingCoordinates = true // Show loading indicator
        locationErrorMessage = nil // Clear previous errors
        hideKeyboard() // Dismiss keyboard after selection

        // Perform MKLocalSearch to get coordinates
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)

        do {
            let response = try await search.start()
            if let mapItem = response.mapItems.first, let coordinate = mapItem.placemark.location?.coordinate {
                self.selectedCoordinate = coordinate
                print("✅ Coordinate found for '\(completion.title)': \(coordinate.latitude), \(coordinate.longitude)")
                // --- DO NOT OVERWRITE locationQuery here ---
            } else {
                print("⚠️ MKLocalSearch succeeded but no coordinate found for '\(completion.title)'")
                locationErrorMessage = "Could not get specific coordinates for this selection."
                selectedCoordinate = nil // Ensure coordinate is nil
                selectedCompletion = nil // Allow user to search again
            }
        } catch {
            print("❌ MKLocalSearch failed for '\(completion.title)': \(error.localizedDescription)")
            locationErrorMessage = "Failed to get coordinates. Please try again or choose another location."
            selectedCoordinate = nil // Ensure coordinate is nil
            selectedCompletion = nil // Allow user to search again
        }
        isSearchingCoordinates = false // Hide loading indicator
    }
    // --- END Function ---

    // Function to clear the form fields and messages
    func clearForm() {
        title = ""
        description = ""
        selectedCategory = categories.first ?? ""
        date = Date()
        // --- Clear location state ---
        locationQuery = ""
        selectedCompletion = nil
        selectedCoordinate = nil
        completerDelegate.searchQuery = "" // Clear completer query too
        completerDelegate.completions = []
        locationErrorMessage = nil
        showSuggestions = false // Reset overlay state
        textFieldFrame = .zero // Reset measured frame
        // --- End clear location state ---
        selectedPhotoItem = nil
        selectedImageData = nil
        selectedImagePreview = nil
        errorMessage = nil
        successMessage = nil
        isLoading = false
        isUploading = false
        isSearchingCoordinates = false
    }

    // Function to post the request to Supabase (REVISED)
    @MainActor
    func postRequest() async {
        hideKeyboard() // Dismiss keyboard before starting

        // Basic validation
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Title cannot be empty."
            successMessage = nil
            return
        }
        // Check if location is entered but coordinates haven't been resolved yet
        guard locationQuery.isEmpty || selectedCoordinate != nil else {
             errorMessage = "Please select a location from the suggestions or clear the location field."
             successMessage = nil
             return
        }
        guard !isLoading, !isUploading, !isSearchingCoordinates else { return }

        isLoading = true // General loading for posting process
        isUploading = false
        errorMessage = nil
        successMessage = nil
        locationErrorMessage = nil // Clear location error too

        // --- GeoPoint is now derived from selectedCoordinate ---
        var geoPoint: GeoJSONPoint? = nil
        if let coordinate = selectedCoordinate {
            geoPoint = GeoJSONPoint(coordinate: coordinate)
        }
        // --- End GeoPoint derivation ---

        var uploadedImageUrl: String? = nil
        var currentUserId: UUID? = nil

        // Get User ID
        do {
             currentUserId = try await supabase.auth.session.user.id
        } catch {
             print("❌ Error getting user ID: \(error)")
             errorMessage = "Could not verify user session. Please try again."
             isLoading = false
             return
        }
        guard let userId = currentUserId else {
             errorMessage = "User session invalid. Please re-login."
             isLoading = false
             return
        }
        let userIdString = userId.uuidString

        // Image Upload Step
        if let imageData = selectedImageData {
            isUploading = true
            isLoading = false // Switch indicator type
            let uniqueFileName = "\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString).jpg"
            let filePath = "\(userIdString)/\(uniqueFileName)"
            print("Uploading image to: \(filePath)")
            do {
                _ = try await supabase.storage.from("request-images").upload(path: filePath, file: imageData, options: FileOptions(contentType: "image/jpeg"))
                let response = try supabase.storage.from("request-images").getPublicURL(path: filePath)
                uploadedImageUrl = response.absoluteString
                print("Image upload successful. URL: \(uploadedImageUrl ?? "N/A")")
            } catch {
                print("❌ Image upload error: \(error)")
                let currentError = errorMessage ?? ""
                errorMessage = "\(currentError)\nFailed to upload image: \(error.localizedDescription)".trimmingCharacters(in: .whitespacesAndNewlines)
                // Decide if you want to stop here if image upload fails
                // isLoading = false; isUploading = false; return
            }
            isUploading = false
            isLoading = true // Switch back to general indicator
        }

        // Supabase Insert Step
        do {
            let finalLocationText = locationQuery.trimmingCharacters(in: .whitespaces)

            let newRequest = RequestParams(
                userId: userId,
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
                category: selectedCategory.isEmpty ? nil : selectedCategory,
                completeBy: date,
                locationText: finalLocationText.isEmpty ? nil : finalLocationText,
                locationGeo: geoPoint, // Use the coordinate derived from MKLocalSearch
                imageUrl: uploadedImageUrl
                // status defaults to "open" in RequestParams
            )

            try await supabase.from("requests").insert(newRequest, returning: .minimal).execute()

            print("Request successfully posted!")
            successMessage = "Request posted successfully!"
            clearForm() // Clear form on success

        } catch {
            print("❌ Error posting request: \(error)")
            let currentError = errorMessage ?? ""
            errorMessage = "\(currentError)\nFailed to post request: \(error.localizedDescription)".trimmingCharacters(in: .whitespacesAndNewlines)
        }

        isLoading = false
        isUploading = false // Ensure reset
    }
}
// --- END STRUCT DEFINITION ---

// Helper to dismiss keyboard
#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif


#Preview {
    NewRequestView()
}
