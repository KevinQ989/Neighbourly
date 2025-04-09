// LeaveReviewView.swift
import SwiftUI
import Supabase

struct LeaveReviewView: View {
    // Input
    let chatId: Int
    let requestId: Int?
    let reviewerId: UUID
    let reviewee: Profile // Profile of the person being reviewed

    // State
    @State private var rating: Int = 0 // 0 means no rating selected yet
    @State private var comment: String = "" // Use 'comment' state var name
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    // Callback
    var onReviewSubmitted: (() -> Void)? // To refresh previous view

    // Environment
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Reviewing \(reviewee.fullName ?? reviewee.username ?? "User")") {
                    // Star Rating Input
                    HStack {
                        Text("Rating:")
                        Spacer()
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .foregroundColor(star <= rating ? .yellow : .gray)
                                .font(.title2) // Make stars slightly larger
                                .onTapGesture {
                                    // Simple set rating on tap:
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                         rating = star
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 5) // Add padding

                    // Comment Input
                    VStack(alignment: .leading) {
                        Text("Comment (Optional)")
                            .font(.caption).foregroundColor(.gray) // Style caption
                        TextEditor(text: $comment) // Bind to 'comment' state variable
                            .frame(height: 150)
                            .border(Color(UIColor.systemGray5), width: 1) // Use border modifier
                            .cornerRadius(5) // Apply corner radius after border
                    }
                }

                // Error/Success Messages
                if let errorMessage {
                    Section { Text(errorMessage).foregroundColor(.red).font(.callout) }
                }
                if let successMessage {
                    Section { Text(successMessage).foregroundColor(.green).font(.callout) }
                }

                // Submit Button
                Section {
                    Button {
                        Task { await submitReviewAction() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white) // Make loader white on blue background
                            } else {
                                Text("Submit Review")
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8) // Add padding inside button
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(rating == 0 || isSubmitting) // Must select a rating
                }
            }
            .navigationTitle("Leave Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting) // Disable cancel while submitting
                }
            }
            // Dismiss keyboard when dragging starts
            .gesture(DragGesture().onChanged { _ in hideKeyboard() })
        }
    }

    // **** THIS FUNCTION IS UPDATED ****
    @MainActor
    func submitReviewAction() async {
        // 1. Guard checks
        guard rating > 0 else {
            errorMessage = "Please select a rating (1-5 stars)."
            return
        }
        guard !isSubmitting else { return } // Prevent double submission

        hideKeyboard() // Dismiss keyboard

        // 2. Set isSubmitting = true, clear errors/success messages
        isSubmitting = true
        errorMessage = nil
        successMessage = nil
        print("➡️ submitReviewAction: Submitting review for chat \(chatId)")

        // 3. Create NewReviewParams object
        //    Using 'description' field based on your preference
        let params = NewReviewParams(
            chatId: chatId,
            requestId: requestId, // Pass along if available
            reviewerId: reviewerId, // Passed into this view
            revieweeId: reviewee.id, // ID of the person being reviewed
            rating: rating,
            description: comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : comment // Use 'comment' state var, map to 'description' key
        )

        // 4. Call Supabase function/RPC to submit review & update chat flag
        do {
            // Use the function defined in DataFetching.swift
            try await supabase.submitReview(params: params)

            // 5. Handle success
            print("✅ submitReviewAction: Review submitted successfully!")
            successMessage = "Review submitted successfully!"
            onReviewSubmitted?() // Trigger callback to refresh ChatDetailView

            // Dismiss after a short delay to show success message
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // Check if success message is still relevant before dismissing
                if self.successMessage != nil {
                    dismiss()
                }
            }
            // Keep isSubmitting = true to prevent further interaction until dismissed

        } catch {
            // 6. Handle error
            print("❌ submitReviewAction: Error submitting review - \(error)")
            errorMessage = "Failed to submit review: \(error.localizedDescription)"
            isSubmitting = false // Allow retry on error
        }
    }
    // **** END UPDATED FUNCTION ****
}


// Preview Provider (Example)
#Preview {
    // Use a sample profile for the reviewee
    let sampleReviewee = Profile(id: UUID(), username: "testUser", fullName: "Test User", website: nil, avatarUrl: nil)

    return LeaveReviewView(
        chatId: 1,
        requestId: 1,
        reviewerId: UUID(), // Dummy reviewer ID
        reviewee: sampleReviewee
    )
}
