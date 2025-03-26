// Models.swift

import Foundation
import CoreLocation // Keep if used by GeoJSONPoint

// MARK: - Profile Models (Existing)

// Profile struct for DECODING data FROM Supabase
struct Profile: Decodable, Identifiable, Equatable { // Add Equatable
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
    var status: String = "open"

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case title
        case description
        case category
        case completeBy = "complete_by"
        case locationText = "location_text"
        case locationGeo = "location_geo" // <-- Map locationGeo
        case imageUrl = "image_url"
        case status
    }
}

// Struct for DECODING request data FROM Supabase
struct RequestData: Decodable, Identifiable, Equatable { // Add Equatable for Map annotations
    let id: Int // Assuming bigint maps to Int
    let userId: UUID
    let title: String
    let description: String?
    let category: String?
    let completeBy: Date?
    let locationText: String?
    let locationGeo: GeoJSONPoint? // <-- Add location_geo field
    let imageUrl: String?
    let status: String
    let createdAt: Date
    // let updatedAt: Date // Add if needed

    // We might want user details too, requires joining tables later
    // let user: Profile?

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
        case status
        case createdAt = "created_at"
        // case updatedAt = "updated_at"
    }

    // Implement Equatable based on ID
    static func == (lhs: RequestData, rhs: RequestData) -> Bool {
        lhs.id == rhs.id
    }

    // Helper to get coordinate for map annotations
    var coordinate: CLLocationCoordinate2D? {
        locationGeo?.coordinate
    }
}


// MARK: - Chat & Message Models (New)

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

// Represents a chat thread, designed for the ChatView list
// Includes information about the *other* participant in the chat
struct Chat: Decodable, Identifiable, Equatable {
    let id: Int // Chat ID
    let requestId: Int? // Optional associated request ID
    let otherParticipant: Profile // Profile of the *other* user in the chat
    // Optional: Add last message preview if needed later
    // let lastMessage: String?
    // let lastMessageTimestamp: Date?
    let createdAt: Date // When the chat was created
    // let updatedAt: Date // When the last activity occurred (requires trigger or manual update)

    enum CodingKeys: String, CodingKey {
        case id
        case requestId = "request_id"
        case otherParticipant = "other_participant_profile" // Alias for joined profile data
        // case lastMessage = "last_message" // Add if fetching last message later
        // case lastMessageTimestamp = "last_message_timestamp" // Add if fetching last message later
        case createdAt = "created_at"
        // case updatedAt = "updated_at"
    }

    // Implement Equatable based on ID
    static func == (lhs: Chat, rhs: Chat) -> Bool {
        lhs.id == rhs.id
    }
}

// Struct for creating a new chat (used when starting chat from RequestDetailView)
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
