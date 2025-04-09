//
//  DataFetching.swift
//  Neighbourly
//
//  Created by Kevin Quah on 6/4/25.
//
import Foundation
import Supabase
import CoreLocation //If you need it here
import SwiftUI // Needed for ReviewError LocalizedError conformance

extension SupabaseClient {
    @MainActor
    func fetchNearbyRequests(
        userCoords: CLLocationCoordinate2D,
        searchRadiusMeters: Double
    ) async throws -> [RequestData] {
        // --- Use Encodable struct for parameters ---
        let params = NearbyRequestsParams(
            user_lon: userCoords.longitude,
            user_lat: userCoords.latitude,
            distance_meters: searchRadiusMeters
        )
        // --- End parameter update ---

        // Call the RPC function using the Encodable struct
        let fetchedData: [RequestData] = try await self
            .rpc("nearby_requests", params: params) // Pass the struct directly
            .execute()
            .value

        return fetchedData
    }

    @MainActor
    func fetchCategories() async throws -> [Category] {
        let fetchedCategories: [Category] = try await self
            .from("categories")
            .select()
            .execute()
            .value

        return fetchedCategories
    }

    // --- THIS FUNCTION MIGHT NEED UPDATING OR REPLACEMENT ---
    // Depending on how ProfileView fetches reviewer name/avatar
    @MainActor
    func fetchMyReviews(
        userId: UUID
    ) async throws -> [Review] {
        // This RPC likely needs to be updated or replaced with a direct query
        // that joins reviews and profiles, as implemented in ProfileView.loadReviews
        print("⚠️ fetchMyReviews RPC called. Consider replacing with direct join query if possible.")

        // Example using direct query (matches ProfileView.loadReviews logic)
        struct ReviewWithReviewer: Decodable, Identifiable {
             let id: UUID
             let chatId: Int
             let requestId: Int?
             let reviewerId: UUID
             let revieweeId: UUID
             let rating: Int
             let description: String?
             let createdAt: Date
             struct ReviewerProfile: Decodable {
                 let fullName: String?
                 let avatarUrl: String?
                 enum CodingKeys: String, CodingKey {
                     case fullName = "full_name"
                     case avatarUrl = "avatar_url"
                 }
             }
             let reviewer: ReviewerProfile?
             enum CodingKeys: String, CodingKey {
                 case id; case chatId = "chat_id"; case requestId = "request_id"
                 case reviewerId = "reviewerid"; case revieweeId = "revieweeid"
                 case rating; case description; case createdAt = "created_at"
                 case reviewer
             }
         }

        let fetchedReviewsWithProfile: [ReviewWithReviewer] = try await self.from("reviews")
             .select("""
                 id, chat_id, request_id, reviewerid, revieweeid, rating, description, created_at,
                 reviewer:reviewerid ( full_name, avatar_url )
             """)
             .eq("revieweeid", value: userId)
             .order("created_at", ascending: false)
             .execute()
             .value

        // Map to the Review model
        let mappedReviews = fetchedReviewsWithProfile.map { fetchedReview -> Review in
             return Review(
                 id: fetchedReview.id,
                 chatId: fetchedReview.chatId,
                 requestId: fetchedReview.requestId,
                 reviewerId: fetchedReview.reviewerId,
                 revieweeId: fetchedReview.revieweeId,
                 rating: fetchedReview.rating,
                 description: fetchedReview.description,
                 createdAt: fetchedReview.createdAt,
                 reviewerName: fetchedReview.reviewer?.fullName,
                 reviewerImageUrl: fetchedReview.reviewer?.avatarUrl
             )
         }
        return mappedReviews

        // --- Original RPC call (commented out as likely needs replacement) ---
        // let params = ReviewParams(
        //     my_id: userId
        // )
        // let fetchedReviews: [Review] = try await self
        //     .rpc("my_reviews", params: params)
        //     // .select() // Select might not be needed after RPC depending on what it returns
        //     .execute()
        //     .value
        // return fetchedReviews
        // --- End Original RPC ---
    }
    // --- END fetchMyReviews ---


    // **** THIS FUNCTION IS NEW / UPDATED ****
    // Function to submit a review and update chat status
    @MainActor
    func submitReview(params: NewReviewParams) async throws {
        // 1. Insert the review into the 'reviews' table
        print("➡️ submitReview: Inserting review into DB for chat \(params.chatId)")
        try await self.from("reviews")
            .insert(params) // Assumes NewReviewParams matches DB columns/keys
            .execute()
        print("   ✅ Review inserted.")

        // 2. Determine which flag to update in the 'chats' table
        //    We need the helperId/requesterId for the chat to know which flag applies to the reviewer.
        //    Fetch the chat record first to get these IDs reliably.
        print("➡️ submitReview: Fetching chat \(params.chatId) to determine reviewer role...")
        struct ChatParticipantIDs: Decodable {
            let requesterId: UUID
            let helperId: UUID
            enum CodingKeys: String, CodingKey {
                case requesterId = "requester_id"
                case helperId = "helper_id"
            }
        }
        let chatInfo: ChatParticipantIDs = try await self.from("chats")
            .select("requester_id, helper_id")
            .eq("id", value: params.chatId)
            .single()
            .execute()
            .value
        print("   ✅ Fetched chat roles: Requester=\(chatInfo.requesterId), Helper=\(chatInfo.helperId)")


        // 3. Determine the correct column name based on the reviewer's role
        let reviewTimestampColumn: String
        if params.reviewerId == chatInfo.helperId {
            reviewTimestampColumn = "helper_reviewed_at"
            print("   ℹ️ Reviewer is the Helper.")
        } else if params.reviewerId == chatInfo.requesterId {
            reviewTimestampColumn = "requester_reviewed_at"
            print("   ℹ️ Reviewer is the Requester.")
        } else {
            // This should not happen if data is consistent
            print("   ⚠️ submitReview: Reviewer ID \(params.reviewerId) doesn't match helper or requester ID for chat \(params.chatId). Cannot update chat flag.")
            // Throw an error or handle appropriately
            struct ReviewError: Error, LocalizedError { let errorDescription: String? = "Reviewer ID mismatch." }
            throw ReviewError()
        }

        // 4. Update the corresponding timestamp in the 'chats' table
        print("➡️ submitReview: Updating '\(reviewTimestampColumn)' in chats table...")
        try await self.from("chats")
            .update([reviewTimestampColumn: Date()]) // Set current timestamp
            .eq("id", value: params.chatId)
            // Optional: Add a check to ensure it hasn't been updated already
            // .is(reviewTimestampColumn, value: "null")
            .execute()
        print("   ✅ Chat table updated.")
        print("✅ submitReview: Process completed successfully.")
    }
    // **** END NEW FUNCTION ****

} // End SupabaseClient extension
