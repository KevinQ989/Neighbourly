// AppView.swift

import SwiftUI // <-- ****** THIS LINE IS CRUCIAL ******
import Foundation
import Supabase

// --- ADD Environment Key ---
struct AuthStateEnvironmentKey: EnvironmentKey {
    static let defaultValue: Bool = false // Default to not authenticated
}

extension EnvironmentValues {
    var isAuthenticatedValue: Bool {
        get { self[AuthStateEnvironmentKey.self] }
        set { self[AuthStateEnvironmentKey.self] = newValue }
    }
}
// --- END Environment Key ---

struct AppView: View {
    // Authentication state
    @State var isAuthenticated = false
    
    // Profile setup state
    @State var needsProfileSetup = false
    @State var checkingAuthState = true // Indicate initial check
    @State var checkingProfile = false // Indicate profile check after auth
    
    var body: some View {
        Group {
            if checkingAuthState {
                // Show a loading indicator while checking initial auth state
                ProgressView("Checking session...")
            } else if !isAuthenticated {
                // User is not logged in, show AuthView
                AuthView()
            } else if checkingProfile {
                // User is logged in, but we are checking if profile exists
                ProgressView("Loading profile...")
            } else if needsProfileSetup {
                // User is logged in, but profile needs to be created/completed
                EditProfileView(onProfileUpdated: {
                    // This callback is triggered from EditProfileView on success
                    print("Profile updated callback received in AppView.")
                    // Re-check profile status or simply assume setup is done
                    // Let's optimistically assume setup is done
                    self.needsProfileSetup = false
                    // Optionally, could re-run checkProfileExists() here for verification
                })
            } else {
                // User is logged in and profile exists, show main app
                TabBarView()
                    .environment(\.isAuthenticatedValue, true)
            }
        }
        .task {
            // This task runs when AppView appears and whenever dependencies change
            // It listens for authentication state changes from Supabase Auth
            print("AppView task started. Setting up auth listener.")
            checkingAuthState = true // Start checking auth
            needsProfileSetup = false // Reset profile state
            checkingProfile = false // Reset profile check state
            
            // Check initial session synchronously (optional but can speed up startup)
            do {
                let initialSession = try await supabase.auth.session
                let sessionIsValid = initialSession != nil
                print("Initial session check: sessionIsValid = \(sessionIsValid)")
                // Update state on main thread
                await MainActor.run { isAuthenticated = sessionIsValid }
                if sessionIsValid {
                    await checkProfileExists()
                }
            } catch {
                print("Error checking initial session: \(error)")
                await MainActor.run { isAuthenticated = false }
            }
            await MainActor.run { checkingAuthState = false }
            
            // Listen for subsequent auth changes (sign in, sign out, token refresh)
            for await state in supabase.auth.authStateChanges {
                let session = state.session
                let event = state.event
                let sessionIsValid = session != nil
                print("Auth state changed: \(event), sessionIsValid: \(sessionIsValid)")
                
                // Use Task to ensure UI updates are on the main thread
                // Although @State updates usually handle this, it's safer within the loop
                await MainActor.run {
                    self.isAuthenticated = sessionIsValid
                    
                    if event == .signedIn {
                        Task { await checkProfileExists() }
                    } else if event == .signedOut {
                        self.needsProfileSetup = false
                        self.checkingProfile = false
                    } else if event == .tokenRefreshed {
                        print("Auth token refreshed.")
                        // Re-check profile if needed, or just ensure isAuthenticated is true
                        if !self.isAuthenticated { self.isAuthenticated = true }
                    } else if event == .userDeleted {
                        print("User deleted.")
                        self.isAuthenticated = false
                        self.needsProfileSetup = false
                        self.checkingProfile = false
                    }
                    // Handle other events like password recovery if needed
                }
            }
            print("Auth listener loop finished (view disappeared?).")
        }
        .environment(\.isAuthenticatedValue, isAuthenticated)
    }
    
    // Function to check if the logged-in user has a profile (Corrected)
    @MainActor // Ensure updates to @State vars happen on main thread
    func checkProfileExists() async {
        guard isAuthenticated else {
            print("checkProfileExists: Not authenticated, skipping check.")
            needsProfileSetup = false
            checkingProfile = false
            return
        }
        
        print("checkProfileExists: Checking profile...")
        checkingProfile = true
        needsProfileSetup = false // Assume profile exists initially
        
        do {
            let userId = try await supabase.auth.session.user.id
            print("checkProfileExists: User ID \(userId)")
            
            // Try to fetch the profile. Select minimal data.
            let fetchedProfile: [Profile] = try await supabase
                .from("profiles")
                .select("id, username") // Select enough fields for Profile struct decoding
                .eq("id", value: userId)
                .limit(1) // Ensure only one row is considered
                .execute() // Execute the query
                .value // Attempt to decode the first (and only) row into Profile?
            
            // Check if a profile was successfully fetched and decoded
            if fetchedProfile.count > 0 {
                // Profile exists
                print("checkProfileExists: Profile found (ID: \(fetchedProfile[0].id)).")
                needsProfileSetup = false
            } else {
                // Profile does not exist (query returned no rows or decoding failed implicitly)
                print("checkProfileExists: Profile not found.")
                needsProfileSetup = true
            }
            
        } catch {
            // Handle potential errors during the fetch/decode process
            print("checkProfileExists: Error during check: \(error)")
            // If an error occurs, it's safer to assume profile setup is needed
            needsProfileSetup = true
        }
        
        checkingProfile = false
        print("checkProfileExists: Finished. needsProfileSetup = \(needsProfileSetup)")
    }
}

// Preview remains unchanged
#Preview {
    AppView()
}
