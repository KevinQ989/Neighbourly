//
//  AuthView.swift
//  Neighbourly
//
//  Created by Kevin Quah on 22/3/25.
//

import Foundation
import SwiftUI
import Supabase

struct AuthView: View {
  @State var email = ""
  @State var isLoading = false
  @State var result: Result<Void, Error>?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // App title
            Text("Neighbourly.")
                .font(.system(size: 32, weight: .bold))
                .padding(.bottom, 60)
            
            // Create account section
            VStack(spacing: 10) {
                Text("Create an account")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Enter your email to sign up for Neighbourly!")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)
                
                Form {
                    Section {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    
                    Section {
                        Button("Sign in") {
                            signInButtonTapped()
                        }
                        
                        if isLoading {
                            ProgressView()
                        }
                    }
                    
                    if let result {
                        Section {
                            switch result {
                            case .success:
                                Text("Check your inbox.")
                            case .failure(let error):
                                Text(error.localizedDescription).foregroundStyle(.red)
                            }
                        }
                    }
                }
                .onOpenURL(perform: { url in
                    Task {
                        do {
                            try await supabase.auth.session(from: url)
                        } catch {
                            self.result = .failure(error)
                        }
                    }
                })
            }
            
            Spacer()
            
            // Terms text
            VStack {
                HStack(spacing: 0) {
                    Text("By clicking continue, you agree to our ")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Button("Terms of Service") {
                        // Open terms
                    }
                    .font(.footnote)
                }
                
                HStack(spacing: 3) {
                    Text("and")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Button("Privacy Policy") {
                        // Open privacy policy
                    }
                    .font(.footnote)
                }
            }
            .padding(.bottom, 20)
            
            // Page indicator
            RoundedRectangle(cornerRadius: 2)
                .frame(width: 40, height: 4)
                .foregroundColor(.black)
                .padding(.bottom, 10)
        }
        .padding()
  }

  func signInButtonTapped() {
    Task {
      isLoading = true
      defer { isLoading = false }

      do {
        try await supabase.auth.signInWithOTP(
            email: email,
            redirectTo: URL(string: "io.supabase.user-management://login-callback")
        )
        result = .success(())
      } catch {
        result = .failure(error)
      }
    }
  }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
    }
}
