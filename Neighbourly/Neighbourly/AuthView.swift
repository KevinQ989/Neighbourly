// AuthView.swift

import Foundation
import SwiftUI
import Supabase

struct AuthView: View {
    @State var email = ""
    @State var isLoading = false
    @State var result: Result<Void, Error>?

    let primaryColor = Color(red: 0.2, green: 0.5, blue: 0.8)
    let backgroundColor = Color(red: 0.96, green: 0.97, blue: 0.98)

    var body: some View {
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "house.fill") // Replace with your custom logo if you have one
                        .font(.system(size: 48))
                        .foregroundColor(primaryColor)

                    Text("Neighbourly")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.black)
                }
                .padding(.bottom, 60)

                VStack(spacing: 16) {
                    // --- Updated Title/Prompt ---
                    Text("Sign In or Sign Up") // Clearer title
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Enter your email to receive a secure sign-in link.") // Updated prompt
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 10)
                    // --- End Update ---

                    VStack(spacing: 20) {
                        TextField("Email", text: $email)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.1), radius: 5)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress) // Ensure keyboard type is set

                        Button(action: signInButtonTapped) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(primaryColor)
                                    .shadow(color: primaryColor.opacity(0.3), radius: 5)

                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Continue with Email") // Slightly more descriptive button
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding()
                                }
                            }
                            .frame(height: 50)
                        }
                        .disabled(isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) // Disable if email is empty

                    }
                    .padding(.horizontal)

                    // Result message display (keep as is)
                    if let result {
                        VStack {
                            switch result {
                            case .success:
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Check your inbox for the sign-in link.")
                                }
                                .foregroundColor(.green)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                            case .failure(let error):
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill")
                                    // Show a more generic error for security maybe?
                                    Text("Error: \(error.localizedDescription)")
                                }
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.top)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 30)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 10)
                .padding(.horizontal)

                Spacer()

                // Terms and Policy (Keep as is)
                VStack(spacing: 3) {
                    HStack(spacing: 0) {
                        Text("By clicking continue, you agree to our ")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        Button("Terms of Service") { /* Open terms */ }
                            .font(.footnote)
                            .foregroundColor(primaryColor)
                    }

                    HStack(spacing: 3) {
                        Text("and")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        Button("Privacy Policy") { /* Open privacy policy */ }
                            .font(.footnote)
                            .foregroundColor(primaryColor)
                    }
                }
                .padding(.bottom, 20)

                // Bottom decoration (Keep as is)
                // RoundedRectangle(cornerRadius: 2)
                //     .frame(width: 40, height: 4)
                //     .foregroundColor(.gray)
                //     .padding(.bottom, 10)
            }
            .padding()
        }
        .onOpenURL(perform: { url in // Keep as is
            Task {
                do {
                    try await supabase.auth.session(from: url)
                } catch {
                    // Use Task @MainActor for UI updates if needed, though @State handles it
                    Task { @MainActor in self.result = .failure(error) }
                }
            }
        })
    }

    func signInButtonTapped() {
        Task { @MainActor in // Ensure state updates are on main thread
            isLoading = true
            result = nil // Clear previous result
            defer { isLoading = false }

            // --- Trim email ---
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            // --- End Trim ---

            guard !trimmedEmail.isEmpty else {
                 // Optionally show an error if email is empty after trimming
                 result = .failure(ValidationError(message: "Email cannot be empty."))
                 return
            }

            do {
                try await supabase.auth.signInWithOTP(
                    email: trimmedEmail, // Use trimmed email
                    redirectTo: URL(string: "io.supabase.user-management://login-callback") // Ensure this matches Supabase settings
                )
                result = .success(())
            } catch {
                result = .failure(error)
            }
        }
    }
}

// Simple validation error struct
struct ValidationError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}


#Preview {
    AuthView()
}
