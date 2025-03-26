// EditProfileView.swift

import SwiftUI
import Foundation
import Supabase
import PhotosUI // <-- Import PhotosUI

struct EditProfileView: View { // Brace 1 Open
    // Profile fields state
    @State var username = ""
    @State var fullName = ""
    @State var website = ""
    @State var avatarUrl = "" // Holds the CURRENT avatar URL from DB

    // Image Picker State
    @State private var selectedAvatarItem: PhotosPickerItem? = nil
    @State private var selectedAvatarData: Data? = nil
    @State private var avatarPreviewImage: Image? = nil // For local preview after selection

    // Loading/Error State
    @State var isLoading = false // General loading for profile fetch/update
    @State var isUploadingAvatar = false // Specific state for avatar upload
    @State private var errorMessage: String?

    // Callback
    var onProfileUpdated: (() -> Void)?

    // Environment
    @Environment(\.dismiss) var dismiss

    var body: some View { // Brace 2 Open
        NavigationView { // Brace 3 Open
            Form { // Brace 4 Open
                // --- Avatar Section ---
                Section("Avatar") { // Brace 5 Open
                    HStack { // Brace 6 Open
                        Spacer() // Center the content
                        VStack { // Brace 7 Open
                            // Display current avatar or selected preview
                            Group { // Group for conditional display
                                if let preview = avatarPreviewImage {
                                    preview // Show selected preview
                                        .resizable()
                                } else if let existingUrl = URL(string: avatarUrl) {
                                    // Show existing avatar from URL
                                    AsyncImage(url: existingUrl) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable()
                                        case .failure, .empty:
                                            // Placeholder if loading fails or no URL
                                            Image(systemName: "person.crop.circle.fill")
                                                .resizable().foregroundColor(.gray)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                } else {
                                    // Default placeholder
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable().foregroundColor(.gray)
                                }
                            }
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle()) // Make it circular
                            .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))

                            // PhotosPicker Button
                            PhotosPicker(
                                selection: $selectedAvatarItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Text(avatarUrl.isEmpty && avatarPreviewImage == nil ? "Select Avatar" : "Change Avatar")
                                    .font(.footnote)
                            }
                            .padding(.top, 5)
                            // Show progress during upload
                            if isUploadingAvatar {
                                ProgressView().padding(.top, 5)
                            }
                        } // Brace 7 Close
                        Spacer() // Center the content
                    } // Brace 6 Close
                    .onChange(of: selectedAvatarItem) { newItem in // Load preview when item changes
                        Task { await loadImagePreview(from: newItem) }
                    }
                } // Brace 5 Close
                // --- End Avatar Section ---

                Section("Details") { // Brace 8 Open
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Full name", text: $fullName)
                        .textContentType(.name)
                    TextField("Website", text: $website)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } // Brace 8 Close

                Section { // Brace 9 Open
                    Button("Update Profile") { // Brace 10 Open
                        Task { // Brace 11 Open
                            await updateOrInsertProfile()
                        } // Brace 11 Close
                    } // Brace 10 Close
                    .bold()
                    .disabled(isLoading || isUploadingAvatar || username.trimmingCharacters(in: .whitespaces).isEmpty)

                    // Show general loading indicator (distinct from avatar upload)
                    if isLoading && !isUploadingAvatar {
                        ProgressView()
                    }
                } // Brace 9 Close

                // Display error message if any
                if let errorMessage { // Brace 12 Open
                    Section { // Brace 13 Open
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                    } // Brace 13 Close
                } // Brace 12 Close
            } // Brace 4 Close
            .navigationTitle("Profile Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { // Brace 14 Open
                ToolbarItem(placement: .navigationBarLeading) { // Brace 15 Open
                    Button("Sign out", role: .destructive) { // Brace 16 Open
                        Task { // Brace 17 Open
                            await self.signOut()
                        } // Brace 17 Close
                    } // Brace 16 Close
                    .disabled(isLoading || isUploadingAvatar) // Disable during operations
                } // Brace 15 Close
            } // Brace 14 Close
            .task { // Brace 18 Open
                // Fetch existing profile when the view appears
                await getInitialProfile()
            } // Brace 18 Close
        } // Brace 3 Close
    } // Brace 2 Close

    // Function to load image preview from PhotosPickerItem
    @MainActor
    func loadImagePreview(from item: PhotosPickerItem?) async {
        guard let item = item else {
            selectedAvatarData = nil
            avatarPreviewImage = nil
            return
        }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                selectedAvatarData = data
                if let uiImage = UIImage(data: data) {
                    avatarPreviewImage = Image(uiImage: uiImage)
                } else {
                    avatarPreviewImage = nil
                    errorMessage = "Selected file is not a valid image."
                }
            } else {
                selectedAvatarData = nil
                avatarPreviewImage = nil
            }
        } catch {
            print("❌ Error loading image data: \(error)")
            errorMessage = "Could not load selected image."
            selectedAvatarData = nil
            avatarPreviewImage = nil
        }
    }


    // Function to fetch the current user's profile
    @MainActor
    func getInitialProfile() async { // Brace 19 Open
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do { // Brace 20 Open
            let session = try await supabase.auth.session
            let userId = session.user.id

            let profile: Profile = try await supabase
                .from("profiles")
                .select() // Select all columns defined in the Profile struct
                .eq("id", value: userId)
                .single()
                .execute()
                .value // Use .value assuming execute returns decoded value

            self.username = profile.username ?? ""
            self.fullName = profile.fullName ?? ""
            self.website = profile.website ?? ""
            self.avatarUrl = profile.avatarUrl ?? "" // Load existing avatar URL

            // Clear any lingering preview if loading existing profile
            self.avatarPreviewImage = nil
            self.selectedAvatarData = nil
            self.selectedAvatarItem = nil

        } catch { // Brace 20 Close, Brace 21 Open
            debugPrint("Error fetching profile (might be expected if new user): \(error)")
            // Clear fields explicitly
            self.username = ""
            self.fullName = ""
            self.website = ""
            self.avatarUrl = ""
        } // Brace 21 Close
    } // Brace 19 Close

    // Function to update or insert the profile
    @MainActor
    func updateOrInsertProfile() async { // Brace 22 Open
        guard !isLoading, !isUploadingAvatar else { return } // Prevent concurrent operations

        isLoading = true // Use general loading indicator for the whole process
        isUploadingAvatar = false // Reset just in case
        errorMessage = nil
        var finalAvatarUrl = self.avatarUrl // Start with existing URL

        do { // Brace 23 Open (Main Update Process)
            let userId = try await supabase.auth.session.user.id

            // --- Upload Avatar if new one selected ---
            if let avatarData = selectedAvatarData { // Brace 24 Open
                isUploadingAvatar = true // Show specific indicator
                isLoading = false // Can hide general one

                let filePath = "\(userId.uuidString)/\(UUID().uuidString).jpg" // Unique path
                print("Uploading new avatar to: \(filePath)")

                do { // Brace 25 Open (Upload do-catch)
                    // Correct FileOptions parameter order
                    _ = try await supabase.storage
                        .from("avatars") // Use avatars bucket
                        .upload(path: filePath, file: avatarData, options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: false)) // cacheControl first

                    // Get public URL after successful upload
                    let response = try supabase.storage
                        .from("avatars")
                        .getPublicURL(path: filePath)
                    finalAvatarUrl = response.absoluteString // Update the URL to save
                    print("Avatar upload successful. URL: \(finalAvatarUrl)")

                    // Clear selection state after successful upload
                    selectedAvatarData = nil
                    selectedAvatarItem = nil

                } catch { // Brace 25 Close, Brace 26 Open
                    print("❌ Avatar upload failed: \(error)")
                    errorMessage = "Failed to upload avatar: \(error.localizedDescription)"
                    isUploadingAvatar = false
                    isLoading = false // Stop loading on failure
                    return // Stop the profile update process if avatar upload fails
                } // Brace 26 Close
                isUploadingAvatar = false
                isLoading = true // Resume general loading for profile update
            } // Brace 24 Close
            // --- End Avatar Upload ---

            // Prepare profile data including the final avatar URL
            let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
            let trimmedFullName = fullName.trimmingCharacters(in: .whitespaces)
            let trimmedWebsite = website.trimmingCharacters(in: .whitespaces)

            if trimmedUsername.isEmpty {
                errorMessage = "Username cannot be empty."
                isLoading = false
                return
            }

            let profileData = UpdateProfileParams(
                id: userId,
                username: trimmedUsername,
                fullName: trimmedFullName,
                website: trimmedWebsite.isEmpty ? nil : trimmedWebsite,
                avatarUrl: finalAvatarUrl.isEmpty ? nil : finalAvatarUrl, // Use final URL
                updatedAt: Date()
            )

            // Perform UPSERT operation
            try await supabase
                .from("profiles")
                .upsert(profileData, returning: .minimal)
                .execute()

            print("Profile successfully upserted.")
            // Update local state to reflect saved avatar URL immediately
            self.avatarUrl = finalAvatarUrl
            // Clear preview as the saved URL is now the source of truth
            self.avatarPreviewImage = nil

            isLoading = false
            onProfileUpdated?() // Trigger callback

        } catch { // Brace 23 Close, Brace 27 Open
            debugPrint("Error updating profile: \(error)")
            if let postgrestError = error as? PostgrestError,
               postgrestError.message.contains("duplicate key value violates unique constraint \"profiles_username_key\"") {
                self.errorMessage = "Username '\(username)' is already taken."
            } else if errorMessage == nil { // Don't overwrite avatar upload error
                self.errorMessage = "Failed to update profile: \(error.localizedDescription)"
            }
            isLoading = false
            isUploadingAvatar = false // Ensure this is off on error too
        } // Brace 27 Close
    } // Brace 22 Close

    // Function to sign out
    @MainActor
    func signOut() async { // Brace 28 Open
        guard !isLoading, !isUploadingAvatar else { return }
        isLoading = true // Use general loading indicator
        errorMessage = nil

        do { // Brace 29 Open
            try await supabase.auth.signOut()
            // AppView listener handles UI change. isLoading will be reset by view disappearing.
        } catch { // Brace 29 Close, Brace 30 Open
            debugPrint("Error signing out: \(error)")
            self.errorMessage = "Failed to sign out: \(error.localizedDescription)"
            isLoading = false // Reset loading only on failure
        } // Brace 30 Close
    } // Brace 28 Close

} // Brace 1 Close

// Preview needs the callback
#Preview { // Brace 31 Open
  EditProfileView(onProfileUpdated: {})
} // Brace 31 Close
