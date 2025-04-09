// Models.swift

import Foundation
import CoreLocation // Keep if used by GeoJSONPoint
import SwiftUICore // Assuming this is needed for Color, otherwise import SwiftUI

// MARK: - Profile Models (Existing)

// Profile struct for DECODING data FROM Supabase
struct Profile: Decodable, Identifiable, Equatable, Hashable { // Add Equatable & Hashable
    let id: UUID
    let username: String?
    let fullName: String?
    let website: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case website
        case avatarUrl = "avatar_url"
    }

    // Implement Equatable based on ID
    static func == (lhs: Profile, rhs: Profile) -> Bool {
        lhs.id == rhs.id
    }
    // Implement Hashable based on ID
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// UpdateProfileParams struct for ENCODING data TO Supabase (for UPSERT)
struct UpdateProfileParams: Encodable {
    let id: UUID
    let username: String
    let fullName: String
    let website: String? // Make optional if allowed
    let avatarUrl: String? // Make optional
    let updatedAt: Date // Keep for tracking updates

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case website
        case avatarUrl = "avatar_url"
        case updatedAt = "updated_at"
    }
}

// MARK: - Geometry Point Model (Existing)

// Represents a geographic point for encoding/decoding with PostGIS geometry
struct GeoJSONPoint: Codable, Hashable { // Add Hashable for potential use in Identifiable structs if needed
    let type: String = "Point" // GeoJSON type
    // Coordinates are [longitude, latitude] in GeoJSON standard
    let coordinates: [Double]

    // Convenience initializer from CLLocationCoordinate2D
    init(coordinate: CLLocationCoordinate2D) {
        // Ensure correct order: [longitude, latitude]
        self.coordinates = [coordinate.longitude, coordinate.latitude]
    }

    // Computed property to get CLLocationCoordinate2D (handles potential array size issues)
    var coordinate: CLLocationCoordinate2D? {
        guard coordinates.count == 2 else { return nil }
        // Ensure correct order: latitude is coordinates[1], longitude is coordinates[0]
        return CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
    }
}


// MARK: - Request Models (Existing)

// Struct for ENCODING data when CREATING a new request
struct RequestParams: Encodable {
    var userId: UUID
    var title: String
    var description: String?
    var category: String?
    var completeBy: Date?
    var locationText: String?
    var locationGeo: GeoJSONPoint? // <-- Add location_geo field using GeoJSONPoint
    var imageUrl: String?
    var open: Bool = true

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case title
        case description
        case category
        case completeBy = "complete_by"
        case locationText = "location_text"
        case locationGeo = "location_geo" // <-- Map locationGeo
        case imageUrl = "image_url"
        case open
    }
}

struct NearbyRequestsParams: Encodable {
    let user_lon: Double
    let user_lat: Double
    let distance_meters: Double
}

struct RequestAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let request: RequestData
}

// Struct for DECODING request data FROM Supabase
struct RequestData: Decodable, Identifiable, Equatable, Hashable { // Add Equatable & Hashable
    let id: Int // Assuming bigint maps to Int
    let userId: UUID
    let title: String
    let description: String?
    let category: String?
    let completeBy: Date?
    let locationText: String?
    let locationGeo: GeoJSONPoint? // <-- Add location_geo field
    let imageUrl: String?
    let open: Bool
    let createdAt: Date
    // let updatedAt: Date // Add if needed

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case description
        case category
        case completeBy = "complete_by"
        case locationText = "location_text"
        case locationGeo = "location_geo" // <-- Map locationGeo
        case imageUrl = "image_url"
        case open
        case createdAt = "created_at"
        // case updatedAt = "updated_at"
    }

    // Implement Equatable based on ID
    static func == (lhs: RequestData, rhs: RequestData) -> Bool {
        return lhs.id == rhs.id
    }
    // Implement Hashable based on ID
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Helper to get coordinate for map annotations
    var coordinate: CLLocationCoordinate2D? {
        locationGeo?.coordinate
    }

    var latitude: Double? {
        locationGeo?.coordinate?.latitude
    }

    var longitude: Double? {
        locationGeo?.coordinate?.longitude
    }
}


// MARK: - Chat & Message Models (Updated)

// Represents an individual message within a chat
struct ChatMessage: Decodable, Identifiable, Hashable {
    let id: Int // Assuming bigint maps to Int
    let chatId: Int // Foreign key to chats table
    let senderId: UUID // Foreign key to profiles table
    let content: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case chatId = "chat_id"
        case senderId = "sender_id"
        case content
        case createdAt = "created_at"
    }
}

struct Category: Identifiable, Decodable {
    // Use categoryid as the id for Identifiable
    var id: Int { categoryid }

    let categoryid: Int
    let categoryname: String
    let color: String // Store color as a string from Supabase
    let imageurl: String

    // Assuming SwiftUICore provides Color or import SwiftUI
    var swiftUIColor: Color {
            getColorFromString(colorName: color)
        }

    //Hard coding FTW
    // Private helper function for color conversion
    private func getColorFromString(colorName: String) -> Color {
        switch colorName.lowercased() { // Make the switch case insensitive
        case "red":
            return .red
        case "blue":
            return .blue
        case "green":
            return .green
        case "yellow":
            return .yellow
        case "orange":
            return .orange
        case "purple":
            return .purple
        case "pink":
            return .pink
        case "gray":
            return .gray
        case "white":
            return .white
        case "black":
            return .black
        default:
            return .gray // Provide a default color if the name is not recognized
        }
    }
}

// Represents a chat thread, designed for the ChatView list
// **** THIS STRUCT IS UPDATED ****
// In Models.swift

struct Chat: Identifiable, Equatable, Hashable {
    let id: Int // Keep as let
    let requestId: Int? // Keep as let
    let otherParticipant: Profile // Keep as let
    var lastMessageContent: String? // Already var
    var lastMessageTimestamp: Date? // Already var
    let createdAt: Date // Keep as let
    let requestTitle: String? // Keep as let
    let requestImageUrl: String? // Keep as let
    let lastMessageSenderId: UUID? // Keep as let
    var isUnread: Bool = false // Already var

    // --- CHANGE THESE FROM let TO var ---
    let requesterId: UUID // Keep as let (doesn't change)
    let helperId: UUID    // Keep as let (doesn't change)
    var offerMadeAt: Date?         // <<< Change to var
    var offerAcceptedAt: Date?     // <<< Change to var
    var helperReviewedAt: Date?    // <<< Change to var
    var requesterReviewedAt: Date? // <<< Change to var
    // --- END CHANGES ---

    // Equatable, Hashable, init(), computed properties remain the same

    // Implement Equatable based on ID
    static func == (lhs: Chat, rhs: Chat) -> Bool {
        lhs.id == rhs.id
    }
    // Implement Hashable based on ID
    func hash(into hasher: inout Hasher) {
         hasher.combine(id)
     }

    // Initializer remains the same (accepts the values)
    init(id: Int, requestId: Int?, otherParticipant: Profile, createdAt: Date,
         lastMessageContent: String? = nil, lastMessageTimestamp: Date? = nil,
         requestTitle: String? = nil, requestImageUrl: String? = nil,
         lastMessageSenderId: UUID? = nil, isUnread: Bool = false,
         requesterId: UUID, helperId: UUID, offerMadeAt: Date? = nil,
         offerAcceptedAt: Date? = nil, helperReviewedAt: Date? = nil,
         requesterReviewedAt: Date? = nil
        ) {
        self.id = id
        self.requestId = requestId
        self.otherParticipant = otherParticipant
        self.createdAt = createdAt
        self.lastMessageContent = lastMessageContent
        self.lastMessageTimestamp = lastMessageTimestamp
        self.requestTitle = requestTitle
        self.requestImageUrl = requestImageUrl
        self.lastMessageSenderId = lastMessageSenderId
        self.isUnread = isUnread
        self.requesterId = requesterId
        self.helperId = helperId
        self.offerMadeAt = offerMadeAt
        self.offerAcceptedAt = offerAcceptedAt
        self.helperReviewedAt = helperReviewedAt
        self.requesterReviewedAt = requesterReviewedAt
    }

    // Computed properties remain the same
    var isOfferMade: Bool { offerMadeAt != nil }
    var isOfferAccepted: Bool { offerAcceptedAt != nil }
    func didCurrentUserReview(currentUserId: UUID?) -> Bool {
        guard let currentUserId = currentUserId else { return false }
        if currentUserId == helperId {
            return helperReviewedAt != nil
        } else if currentUserId == requesterId {
            return requesterReviewedAt != nil
        }
        print("⚠️ didCurrentUserReview check: currentUserId \(currentUserId) is neither helper (\(helperId)) nor requester (\(requesterId))")
        return false
    }
}

// **** END UPDATED Chat STRUCT ****


// Struct for creating a new chat
struct NewChatParams: Encodable {
    let requestId: Int?
    let requesterId: UUID
    let helperId: UUID

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case requesterId = "requester_id"
        case helperId = "helper_id"
    }
}

// Struct for sending a new message
struct NewMessageParams: Encodable {
    let chatId: Int
    let senderId: UUID
    let content: String

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case senderId = "sender_id"
        case content
        // createdAt is handled by database default
    }
}

// MARK: - Review Models (Updated)

// Struct for fetching reviews (matches corrected DB structure)
// **** THIS STRUCT IS UPDATED ****
struct Review: Identifiable, Decodable {
    let id: UUID // Added PK
    let chatId: Int // Added FK (use Int to match BIGINT/int8)
    let requestId: Int? // Added FK (Optional if nullable in DB)
    let reviewerId: UUID // Matches 'reviewerid' column
    let revieweeId: UUID // Matches 'revieweeid' column
    let rating: Int
    let description: String? // Matches 'description' column, make optional if nullable
    let createdAt: Date // Added timestamp

    // --- ADDED for ProfileView Card ---
    var reviewerName: String? // Store fetched name
    var reviewerImageUrl: String? // Store fetched URL
    // --- END ADDED ---

    enum CodingKeys: String, CodingKey {
        case id
        case chatId = "chat_id"
        case requestId = "request_id"
        case reviewerId = "reviewerid" // <-- Use DB column name 'reviewerid'
        case revieweeId = "revieweeid" // <-- Use DB column name 'revieweeid'
        case rating
        case description // <-- Use DB column name 'description'
        case createdAt = "created_at"

        // --- ADDED CodingKeys if fetching joined data ---
        // Adjust these based on your actual fetch query in ProfileView/loadReviews
        case reviewerName = "reviewer_full_name" // Example if joined
        case reviewerImageUrl = "reviewer_avatar_url" // Example if joined
        // --- END ADDED ---
    }
}
// **** END UPDATED Review STRUCT ****


// Struct for submitting a new review
// **** THIS STRUCT IS UPDATED ****
struct NewReviewParams: Encodable {
    let chatId: Int // Use Int for BIGINT/int8
    let requestId: Int? // Optional
    let reviewerId: UUID // Swift variable name
    let revieweeId: UUID // Swift variable name
    let rating: Int
    let description: String? // Swift variable name

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case requestId = "request_id"
        case reviewerId = "reviewerid" // <-- Map to DB column 'reviewerid'
        case revieweeId = "revieweeid" // <-- Map to DB column 'revieweeid'
        case rating
        case description // <-- Map to DB column 'description'
    }
}
// **** END UPDATED NewReviewParams STRUCT ****


// Struct for fetching reviews via RPC (if used)
struct ReviewParams: Encodable {
    let my_id: UUID
}
