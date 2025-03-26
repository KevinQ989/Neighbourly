// EditProfileView.swift

import SwiftUI
import Foundation
import Supabase

struct EditProfileView: View { // Brace 1 Open
    // State variables for the form fields
    @State var username = ""
    @State var fullName = ""
    @State var website = ""
    @State var avatarUrl = "" // Add state for avatar URL if you plan to edit it

    @State var isLoading = false
    @State private var errorMessage: String? // To show errors to the user

    // Callback to notify parent view (AppView) that profile is updated/created
    var onProfileUpdated: (() -> Void)?

    // Environment variable to dismiss the view if needed
    @Environment(\.dismiss) var dismiss

    var body: some View { // Brace 2 Open
        // Using NavigationView for broader compatibility example
        NavigationView { // Brace 3 Open
            Form { // Brace 4 Open
                Section { // Brace 5 Open
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
                    // Optional: Add TextField for avatarUrl
                } // Brace 5 Close

                Section { // Brace 6 Open
                    Button("Update Profile") { // Brace 7 Open (Button Action)
                        Task { // Brace 8 Open (Task)
                            await self.updateOrInsertProfile() // Use self explicitly
                        } // Brace 8 Close (Task)
                    } // Brace 7 Close (Button Action)
                    .bold()
                    .disabled(isLoading || username.trimmingCharacters(in: .whitespaces).isEmpty)

                    if isLoading { // Brace 9 Open (if)
                        ProgressView()
                    } // Brace 9 Close (if)
                } // Brace 6 Close

                // Display error message if any
                if let errorMessage { // Brace 10 Open (if-let)
                    Section { // Brace 11 Open
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                    } // Brace 11 Close
                } // Brace 10 Close (if-let)
            } // Brace 4 Close
            .navigationTitle("Profile Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { // Brace 12 Open (toolbar content)
                ToolbarItem(placement: .navigationBarLeading) { // Brace 13 Open (ToolbarItem content)
                    Button("Sign out", role: .destructive) { // Brace 14 Open (Button Action)
                        Task { // Brace 15 Open (Task)
                            // Line 76 area: Use self explicitly
                            await self.signOut()
                        } // Brace 15 Close (Task)
                    } // Brace 14 Close (Button Action)
                    .disabled(isLoading)
                } // Brace 13 Close (ToolbarItem content)
            } // Brace 12 Close (toolbar content)
            .task { // Brace 16 Open (task modifier)
                // Fetch existing profile when the view appears
                await self.getInitialProfile() // Use self explicitly
            } // Brace 16 Close (task modifier)
        } // Brace 3 Close
    } // Brace 2 Close

    // Function to fetch the current user's profile
    @MainActor
    func getInitialProfile() async { // Brace 17 Open
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do { // Brace 18 Open (do)
            let session = try await supabase.auth.session
            let userId = session.user.id

            let profile: Profile = try await supabase
                .from("profiles")
                .select() // Select all columns defined in the Profile struct
                .eq("id", value: userId) // Filter by the user's ID
                .single() // Expect exactly one row or throw an error
                .execute()
                .value // Decode the result into our Profile struct

            self.username = profile.username ?? ""
            self.fullName = profile.fullName ?? ""
            self.website = profile.website ?? ""
            self.avatarUrl = profile.avatarUrl ?? ""

        } catch { // Brace 18 Close (do), Brace 19 Open (catch)
            debugPrint("Error fetching profile (might be expected if new user): \(error)")
            self.username = ""
            self.fullName = ""
            self.website = ""
            self.avatarUrl = ""
        } // Brace 19 Close (catch)
    } // Brace 17 Close

    // Function to update or insert the profile
    @MainActor
    func updateOrInsertProfile() async { // Brace 20 Open
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do { // Brace 21 Open (do)
            let userId = try await supabase.auth.session.user.id

            let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
            let trimmedFullName = fullName.trimmingCharacters(in: .whitespaces)
            let trimmedWebsite = website.trimmingCharacters(in: .whitespaces)
            let trimmedAvatarUrl = avatarUrl.trimmingCharacters(in: .whitespaces)

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
                avatarUrl: trimmedAvatarUrl.isEmpty ? nil : trimmedAvatarUrl,
                updatedAt: Date()
            )

            try await supabase
                .from("profiles")
                .upsert(profileData, returning: .minimal)
                .execute()

            print("Profile successfully upserted.")
            isLoading = false
            onProfileUpdated?()

        } catch { // Brace 21 Close (do), Brace 22 Open (catch)
            debugPrint("Error updating profile: \(error)")
            if let postgrestError = error as? PostgrestError,
               postgrestError.message.contains("duplicate key value violates unique constraint \"profiles_username_key\"") {
                self.errorMessage = "Username '\(username)' is already taken. Please choose another."
            } else {
                self.errorMessage = "Failed to update profile: \(error.localizedDescription)"
            }
            isLoading = false
        } // Brace 22 Close (catch)
    } // Brace 20 Close

    // Function to sign out
    @MainActor
    func signOut() async { // Brace 23 Open
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do { // Brace 24 Open (do)
            // Line 141: This try should be handled by the catch block
            try await supabase.auth.signOut()
            // If signOut succeeds, isLoading remains true, AppView handles UI change
        } catch { // Brace 24 Close (do), Brace 25 Open (catch)
            // This catch block handles errors from the try above
            debugPrint("Error signing out: \(error)")
            self.errorMessage = "Failed to sign out: \(error.localizedDescription)"
            isLoading = false // Set loading to false only if sign out fails
        } // Brace 25 Close (catch)
    } // Brace 23 Close

} // Brace 1 Close - This is the closing brace for the struct EditProfileView

// Preview
#Preview { // Brace 26 Open
    EditProfileView(onProfileUpdated: {})
} // Brace 26 Close - This is the closing brace for the Preview
