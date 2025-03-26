// NewRequestView.swift

import SwiftUI
import Supabase
import CoreLocation
import PhotosUI // <-- Import PhotosUI

struct NewRequestView: View { // Brace 1 Open
    // Form fields
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedCategory: String = ""
    @State private var date: Date = Date()
    @State private var location: String = "" // Address string

    // --- Image Picker State ---
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var selectedImagePreview: Image? = nil // Optional Image
    // --- End Image Picker State ---

    // State for Supabase interaction
    @State private var isLoading = false
    @State private var isGeocoding = false
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    // Geocoder instance
    private let geocoder = CLGeocoder()

    // Hardcoded categories
    let categories = ["Moving Help", "Tech", "Groceries", "Pet Care", "Home Repair", "Other"]

    init() {
        _selectedCategory = State(initialValue: categories.first ?? "")
    }

    var body: some View { // Brace 2 Open
        NavigationView { // Brace 3 Open
            VStack { // Brace 4 Open
                Form { // Brace 5 Open
                    Section(header: Text("Request Details")) { // Brace 6 Open
                        TextField("Title (Required)", text: $title)

                        VStack(alignment: .leading) { // Brace 7 Open
                            Text("Description")
                                .font(.caption).foregroundColor(.gray)
                            TextEditor(text: $description)
                                .frame(height: 100)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.2)))
                        } // Brace 7 Close

                        Picker("Category", selection: $selectedCategory) { // Brace 8 Open
                            ForEach(categories, id: \.self) { category in // Brace 9 Open
                                Text(category)
                            } // Brace 9 Close
                        } // Brace 8 Close

                        DatePicker("Complete By", selection: $date, displayedComponents: [.date, .hourAndMinute])

                        TextField("Location Address/Area", text: $location)
                    } // Brace 6 Close

                    // --- Updated Image Section ---
                    Section(header: Text("Image (Optional)")) { // Brace 10 Open
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
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    self.selectedImageData = data
                                    if let uiImage = UIImage(data: data) {
                                        self.selectedImagePreview = Image(uiImage: uiImage)
                                    } else {
                                        self.selectedImagePreview = nil
                                    }
                                } else {
                                    self.selectedImageData = nil
                                    self.selectedImagePreview = nil
                                }
                            }
                        }
                    } // Brace 10 Close
                    // --- End Updated Image Section ---

                    // Display messages
                    if let successMessage { // Brace 12 Open
                        Section {
                           Text(successMessage)
                                .foregroundColor(.green)
                        }
                    } // Brace 12 Close
                    if let errorMessage { // Brace 13 Open
                         Section {
                            Text(errorMessage)
                                .foregroundColor(.red)
                         }
                    } // Brace 13 Close

                    // Action Buttons Section
                    Section { // Brace 14 Open
                        HStack(spacing: 20) { // Brace 15 Open
                            Button("Clear Form", role: .destructive) { // Brace 16 Open
                                clearForm()
                            } // Brace 16 Close
                            .disabled(isLoading || isGeocoding || isUploading)

                            Spacer()

                            Button { // Brace 17 Open
                                Task { // Brace 18 Open
                                    await postRequest()
                                } // Brace 18 Close
                            } label: { // Brace 17 Close
                                if isLoading || isGeocoding || isUploading {
                                    ProgressView()
                                        .frame(maxWidth: .infinity, alignment: .center)
                                } else {
                                    Text("Post Request")
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isLoading || isGeocoding || isUploading || title.trimmingCharacters(in: .whitespaces).isEmpty)

                        } // Brace 15 Close
                    } // Brace 14 Close
                } // Brace 5 Close
            } // Brace 4 Close
            .navigationTitle("New Request")
            .navigationBarTitleDisplayMode(.inline)
        } // Brace 3 Close
    } // Brace 2 Close

    // Function to clear the form fields and messages
    func clearForm() { // Brace 21 Open
        title = ""
        description = ""
        selectedCategory = categories.first ?? ""
        date = Date()
        location = ""
        selectedPhotoItem = nil
        selectedImageData = nil
        selectedImagePreview = nil
        errorMessage = nil
        successMessage = nil
    } // Brace 21 Close

    // Function to post the request to Supabase
    @MainActor
    func postRequest() async { // Brace 22 Open
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Title cannot be empty."
            successMessage = nil
            return
        }
        guard !isLoading, !isGeocoding, !isUploading else { return }

        isLoading = true
        isGeocoding = false
        isUploading = false
        errorMessage = nil
        successMessage = nil

        var geoPoint: GeoJSONPoint? = nil
        var uploadedImageUrl: String? = nil
        var currentUserId: UUID? = nil

        // --- Get User ID First ---
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


        // --- Geocoding Step ---
        let addressString = location.trimmingCharacters(in: .whitespaces)
        if !addressString.isEmpty { // Brace 23 Open
            isGeocoding = true
            isLoading = false
            print("Geocoding address: \(addressString)")
            do { // Brace 24 Open
                let placemarks = try await geocoder.geocodeAddressString(addressString)
                if let coordinate = placemarks.first?.location?.coordinate { // Brace 25 Open
                    geoPoint = GeoJSONPoint(coordinate: coordinate)
                    print("Geocoding successful: \(coordinate.latitude), \(coordinate.longitude)")
                } else { // Brace 25 Close, Brace 26 Open
                    print("Geocoding warning: Address found but no coordinates.")
                } // Brace 26 Close
            } catch { // Brace 24 Close, Brace 27 Open
                print("Geocoding error: \(error.localizedDescription)")
                errorMessage = "Could not find coordinates for location. Posting without map location."
            } // Brace 27 Close
            isGeocoding = false
        } // Brace 23 Close

        // --- Image Upload Step ---
        if let imageData = selectedImageData { // Brace 28 Open
            isUploading = true
            isLoading = false

            let uniqueFileName = "\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString).jpg"
            let filePath = "\(userIdString)/\(uniqueFileName)"

            print("Uploading image to: \(filePath)")

            do { // Brace 31 Open (Upload do-catch)
                _ = try await supabase.storage
                    .from("request_images")
                    .upload(path: filePath, file: imageData, options: FileOptions(contentType: "image/jpeg"))

                // ****** FIX: Add try ******
                let response = try supabase.storage
                    .from("request_images")
                    .getPublicURL(path: filePath)
                // ****** END FIX ******

                uploadedImageUrl = response.absoluteString
                print("Image upload successful. URL: \(uploadedImageUrl ?? "N/A")")

            } catch { // Brace 31 Close, Brace 32 Open
                print("❌ Image upload error: \(error)")
                let currentError = errorMessage ?? ""
                errorMessage = "\(currentError)\nFailed to upload image: \(error.localizedDescription)".trimmingCharacters(in: .whitespacesAndNewlines)
            } // Brace 32 Close
            isUploading = false
        } // Brace 28 Close

        // --- Supabase Insert Step ---
        isLoading = true

        do { // Brace 33 Open (Supabase do-catch)
            // Use the already fetched userId
            let newRequest = RequestParams(
                userId: userId, // Use fetched userId
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
                category: selectedCategory.isEmpty ? nil : selectedCategory,
                completeBy: date,
                locationText: addressString.isEmpty ? nil : addressString,
                locationGeo: geoPoint,
                imageUrl: uploadedImageUrl
            )

            try await supabase
                .from("requests")
                .insert(newRequest, returning: .minimal)
                .execute()

            print("Request successfully posted!")
            successMessage = "Request posted successfully!"
            clearForm()

        } catch { // Brace 33 Close, Brace 34 Open
            print("❌ Error posting request: \(error)")
            let currentError = errorMessage ?? ""
            errorMessage = "\(currentError)\nFailed to post request: \(error.localizedDescription)".trimmingCharacters(in: .whitespacesAndNewlines)
        } // Brace 34 Close

        isLoading = false
    } // Brace 22 Close

} // Brace 1 Close

#Preview { // Brace 35 Open
    NewRequestView()
} // Brace 35 Close
