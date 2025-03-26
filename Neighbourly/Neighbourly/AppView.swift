// AppView.swift

import SwiftUI // <-- ****** THIS LINE IS CRUCIAL ******
import Foundation
import Supabase

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
          isAuthenticated = initialSession != nil
          print("Initial session check: isAuthenticated = \(isAuthenticated)")

          if isAuthenticated {
              await checkProfileExists() // Check profile immediately if already logged in
          }
      } catch {
          print("Error checking initial session: \(error)")
          isAuthenticated = false // Assume not authenticated if error
      }
      checkingAuthState = false // Finished initial auth check

      // Listen for subsequent auth changes (sign in, sign out, token refresh)
      for await state in supabase.auth.authStateChanges {
          let session = state.session
          let event = state.event
          print("Auth state changed: \(event), session: \(session != nil)")

          // Use Task to ensure UI updates are on the main thread
          // Although @State updates usually handle this, it's safer within the loop
          await MainActor.run {
              self.isAuthenticated = session != nil

              if event == .signedIn {
                  // User just signed in, check if their profile exists
                  // Need to wrap async call in Task if not already in one
                  Task { await checkProfileExists() }
              } else if event == .signedOut {
                  // User signed out, reset profile state
                  self.needsProfileSetup = false
                  self.checkingProfile = false
              }
              // Handle other events like password recovery if needed
          }
      }
      print("Auth listener loop finished (should not happen unless view disappears).")
    }
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
      let fetchedProfile: Profile? = try await supabase
        .from("profiles")
        .select("id, username") // Select enough fields for Profile struct decoding
        .eq("id", value: userId)
        .limit(1) // Ensure only one row is considered
        .execute() // Execute the query
        .value // Attempt to decode the first (and only) row into Profile?

      // Check if a profile was successfully fetched and decoded
      if fetchedProfile != nil {
        // Profile exists
        print("checkProfileExists: Profile found (ID: \(fetchedProfile!.id)).")
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
