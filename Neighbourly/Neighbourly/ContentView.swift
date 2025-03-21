import SwiftUI

struct ContentView: View {
    @Binding var isLoggedIn: Bool
    @State private var email: String = ""
    @State private var isLoading: Bool = false
    
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
                
                // Email text field
                TextField("email@domain.com", text: $email)
                    .padding()
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(8)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .padding(.horizontal)
                
                // Continue button
                Button(action: {
                    
                    // Simulate button press
                    withAnimation {
                        isLoggedIn = true
                        isLoading = true
                    }
                    
                    // Simulate network request
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isLoading = false
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Continue")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .foregroundColor(.white)
                .background(Color.black)
                .cornerRadius(8)
                .padding(.horizontal)
                .disabled(isLoading)
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
    
    @ViewBuilder
    func socialLoginButton(text: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                
                Text(text)
                    .fontWeight(.medium)
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .foregroundColor(.primary)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(isLoggedIn: .constant(false))
    }
}
