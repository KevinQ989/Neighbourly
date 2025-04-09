// ChatDetailView.swift

import SwiftUI
import Supabase
import Combine // Import Combine

// RPC Parameter Structs (can stay here or move to Models.swift)
struct MakeOfferRPCParams: Encodable {
    let chat_id_param: Int
    let helper_id_param: UUID
}
struct AcceptOfferRPCParams: Encodable {
    let chat_id_param: Int
    let requester_id_param: UUID
}

struct ChatDetailView: View {

    // --- Use ViewModel for State ---
    @StateObject private var viewModel: ChatDetailViewModel

    // --- Keep UI-specific State ---
    @State private var newMessageText: String = "" // For the text input field
    @State private var scrollViewProxy: ScrollViewProxy? = nil // For scrolling messages
    // **** CHANGED State for Sheet Presentation ****
    @State private var revieweeForSheet: Profile? = nil // Holds item to trigger sheet
    // **** REMOVED showingLeaveReviewSheet and revieweeProfile ****


    // Date Formatter for message timestamps (can stay or move)
    private var messageTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none // No date part
        formatter.timeStyle = .short // e.g., 10:30 AM
        return formatter
    }()

    // --- UPDATED Initializer ---
    init(chat: Chat) {
        // Create the ViewModel instance, passing the initial chat data
        // This initializes the @StateObject
        self._viewModel = StateObject(wrappedValue: ChatDetailViewModel(chat: chat))
    }
    // --- END UPDATED Initializer ---

    var body: some View {
        VStack(spacing: 0) { // Main container

            // --- Action Buttons (Read state from ViewModel) ---
            if let currentUserId = viewModel.currentUserId { // Ensure user ID is loaded from ViewModel
                VStack(spacing: 5) { // Container for buttons and error message
                    // Display Action Error if present (from ViewModel)
                    if let actionError = viewModel.actionError {
                         Text(actionError)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                            .padding(.bottom, 2)
                    }

                    // --- Offer Help Button ---
                    // Visible if current user is the HELPER and no offer has been made yet
                    if currentUserId == viewModel.chatData.helperId && !viewModel.chatData.isOfferMade {
                        Button {
                            Task { await viewModel.performMakeOffer() } // Call ViewModel action
                        } label: {
                            Label("Offer Help", systemImage: "hands.sparkles.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(.green)
                        .disabled(viewModel.isLoadingOffer || viewModel.isLoadingAccept) // Read loading state from ViewModel
                        .overlay(viewModel.isLoadingOffer ? ProgressView().scaleEffect(0.7).tint(.white) : nil) // Read loading state
                        .padding(.horizontal)
                    }

                    // --- Accept Help Button ---
                    // Visible if current user is the REQUESTER, an offer WAS made, and it HASN'T been accepted yet
                    if currentUserId == viewModel.chatData.requesterId && viewModel.chatData.isOfferMade && !viewModel.chatData.isOfferAccepted {
                        Button {
                            Task { await viewModel.performAcceptOffer() } // Call ViewModel action
                        } label: {
                            Label("Accept Help", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(.blue)
                        .disabled(viewModel.isLoadingOffer || viewModel.isLoadingAccept) // Read loading state
                        .overlay(viewModel.isLoadingAccept ? ProgressView().scaleEffect(0.7).tint(.white) : nil) // Read loading state
                        .padding(.horizontal)
                    }

                    // --- Leave Review Button (Action Updated) ---
                    // Visible if offer HAS been accepted AND current user hasn't reviewed yet
                    if viewModel.chatData.isOfferAccepted && !viewModel.chatData.didCurrentUserReview(currentUserId: currentUserId) {
                        Button {
                            // **** CHANGE: Set the item to trigger the sheet ****
                            self.revieweeForSheet = viewModel.chatData.otherParticipant
                            // Error handling if participant is somehow nil (unlikely)
                            if self.revieweeForSheet == nil {
                                viewModel.actionError = "Could not identify user to review."
                                print("⚠️ Error: Could not get revieweeForSheet from viewModel.chatData.otherParticipant")
                            }
                            // **** END CHANGE ****
                        } label: {
                            Label("Leave Review for \(viewModel.chatData.otherParticipant.username ?? "User")", systemImage: "star.leadinghalf.filled")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding(.horizontal)
                        // No need for .disabled modifier here anymore
                    }
                }
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGray6))
                // Add divider only if any action buttons are potentially visible
                if (currentUserId == viewModel.chatData.helperId && !viewModel.chatData.isOfferMade) ||
                   (currentUserId == viewModel.chatData.requesterId && viewModel.chatData.isOfferMade && !viewModel.chatData.isOfferAccepted) ||
                   (viewModel.chatData.isOfferAccepted && !viewModel.chatData.didCurrentUserReview(currentUserId: currentUserId)) {
                    Divider().padding(.bottom, 0)
                }
            }
            // --- End Action Buttons ---


            // --- Message List (Reads from ViewModel) ---
            messageListView // Extracted computed property using ViewModel data
            // --- End Message List ---

        } // End Main VStack
        .safeAreaInset(edge: .bottom) { // Input area pushed above keyboard
            messageInputArea // Extracted computed property using ViewModel action
        }
        .navigationTitle(viewModel.chatData.otherParticipant.fullName ?? viewModel.chatData.otherParticipant.username ?? "Chat") // Title from ViewModel
        .navigationBarTitleDisplayMode(.inline)
        .task { // Use .task to call ViewModel's setup and cleanup
            await viewModel.setupChat()
            return {
                 Task { await viewModel.cleanup() }
            }()
        }
        // **** UPDATED Sheet Modifier ****
        .sheet(item: $revieweeForSheet) { reviewee in // Use .sheet(item:), 'reviewee' is the non-nil Profile
            // Ensure currentUserId is available when sheet presents
            if let reviewerId = viewModel.currentUserId {
                LeaveReviewView(
                    chatId: viewModel.chatData.id,
                    requestId: viewModel.chatData.requestId,
                    reviewerId: reviewerId,
                    reviewee: reviewee, // Pass the non-nil reviewee from the closure
                    onReviewSubmitted: {
                        // Refresh chat data via ViewModel after review submission
                        Task { await viewModel.fetchChatDetails() }
                    }
                )
            } else {
                // Handle case where userId became nil unexpectedly
                Text("Error: User session lost.")
            }
        }
        // **** END UPDATED Sheet Modifier ****

    } // End body

    // --- Update messageListView to use ViewModel ---
    @ViewBuilder
    private var messageListView: some View {
        Group {
            // Read loading/error/data states from viewModel
            if viewModel.isLoadingMessages && viewModel.messages.isEmpty {
                VStack { Spacer(); ProgressView("Loading Messages..."); Spacer() }.frame(maxHeight: .infinity)
            } else if let errorMessage = viewModel.messageError {
                VStack { Text("Error: \(errorMessage)").foregroundColor(.red); Button("Retry") { Task { await viewModel.fetchMessages() } } }.padding().frame(maxHeight: .infinity) // Call viewModel action
            } else if viewModel.messages.isEmpty {
                 VStack { Spacer(); Text("No messages yet. Start the conversation!").foregroundColor(.secondary); Spacer() }.frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Iterate over messages from viewModel
                            ForEach(viewModel.messages) { message in
                                // Request Context Logic (reads viewModel.associatedRequest)
                                if message.id == viewModel.messages.first?.id, let assocReq = viewModel.associatedRequest {
                                    NavigationLink(destination: RequestDetailView(request: assocReq)) {
                                        RequestContextView(request: assocReq)
                                    }
                                    .padding(.vertical, 5)
                                    .buttonStyle(.plain)
                                }
                                // Message Bubble (reads viewModel.currentUserId)
                                MessageView(
                                    message: message,
                                    isCurrentUser: message.senderId == viewModel.currentUserId,
                                    formatter: messageTimestampFormatter
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .onAppear {
                        scrollViewProxy = proxy // Keep local proxy state
                        if !viewModel.messages.isEmpty { scrollToBottom(proxy: proxy, animated: false) }
                    }
                    .onChange(of: viewModel.messages) { _ in scrollToBottom(proxy: scrollViewProxy) } // Use local proxy state
                }
            }
        }
    }

    // --- Update messageInputArea to use ViewModel ---
    private var messageInputArea: some View {
        HStack(alignment: .bottom) {
            TextEditor(text: $newMessageText) // Bind to local @State for input
                .frame(minHeight: 30, maxHeight: 100)
                .padding(4)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(UIColor.systemGray4)))

            Button {
                // Call ViewModel's send message function, passing text and callback
                viewModel.sendMessage(text: newMessageText) {
                    // Callback clears the local text field state
                    newMessageText = ""
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(newMessageText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
            }
            // Disable based on local text state (add viewModel.isSendingMessage if implemented)
            .disabled(newMessageText.trimmingCharacters(in: .whitespaces).isEmpty /* || viewModel.isSendingMessage */)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }

    // --- Update scrollToBottom to use ViewModel ---
    // Takes proxy as input, reads messages from viewModel
    private func scrollToBottom(proxy: ScrollViewProxy?, animated: Bool = true) {
        guard let proxy = proxy, let lastMessageId = viewModel.messages.last?.id else { return } // Read from viewModel
        if animated {
            withAnimation(.spring()) { proxy.scrollTo(lastMessageId, anchor: .bottom) }
        } else {
            proxy.scrollTo(lastMessageId, anchor: .bottom)
        }
    }

    // --- REMOVED Functions that were moved to ViewModel ---

} // End ChatDetailView

// --- RequestContextView, MessageView, RoundedCorner (Unchanged) ---
struct RequestContextView: View {
    let request: RequestData
    var body: some View {
        HStack(spacing: 8) {
            AsyncImage(url: URL(string: request.imageUrl ?? "")) { phase in
                 switch phase {
                 case .empty: ZStack { Rectangle().fill(Color.gray.opacity(0.1)); ProgressView() }
                 case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                 case .failure: ZStack { Rectangle().fill(Color.gray.opacity(0.1)); Image(systemName: "photo.fill").foregroundColor(.gray) }
                 @unknown default: EmptyView()
                 }
             }
             .frame(width: 40, height: 40).clipped().cornerRadius(5)
            VStack(alignment: .leading) {
                 Text("Regarding Request:")
                     .font(.caption2)
                     .foregroundColor(.gray)
                 Text(request.title)
                     .font(.caption)
                     .fontWeight(.medium)
                     .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.gray)
        }
        .padding(8)
        .background(Color(UIColor.systemGray5))
        .cornerRadius(8)
    }
}
struct MessageView: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    let formatter: DateFormatter
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedCorner(radius: 12, corners: [.topLeft, .topRight, .bottomLeft]))
                    Text(formatter.string(from: message.createdAt))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.systemGray5))
                        .foregroundColor(Color(UIColor.label))
                        .clipShape(RoundedCorner(radius: 12, corners: [.topLeft, .topRight, .bottomRight]))
                    Text(formatter.string(from: message.createdAt))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
        }
    }
}
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
// --- End Unchanged Subviews ---


// --- Preview Provider (Uses ViewModel Initializer) ---
#Preview {
    // Create sample data
    let sampleOtherProfile = Profile(id: UUID(), username: "previewUser", fullName: "Preview User", website: nil, avatarUrl: nil)
    let sampleRequesterId = UUID()
    let sampleHelperId = UUID()
    let sampleChat = Chat(
        id: 99, requestId: 1, otherParticipant: sampleOtherProfile, createdAt: Date(),
        requesterId: sampleRequesterId, helperId: sampleHelperId,
        offerMadeAt: Date(), offerAcceptedAt: Date(), helperReviewedAt: nil, requesterReviewedAt: nil // Simulate accepted offer for preview
    )
    NavigationView {
        ChatDetailView(chat: sampleChat) // View initializer creates the ViewModel
    }
}
