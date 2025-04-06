// Models.swift

import Foundation
import CoreLocation // Keep if used by GeoJSONPoint
import SwiftUICore

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
struct Chat: Identifiable, Equatable, Hashable { // Removed Decodable for now as we construct manually
    let id: Int // Chat ID
    let requestId: Int? // Optional associated request ID
    let otherParticipant: Profile // Profile of the *other* user in the chat
    var lastMessageContent: String? // Mutable for combining results
    var lastMessageTimestamp: Date? // Mutable for combining results
    let createdAt: Date // When the chat was created
    
    // --- ADDED Properties for Request Context ---
    let requestTitle: String?
    let requestImageUrl: String?
    // --- END ADDED Properties ---
    
    let lastMessageSenderId: UUID?
    var isUnread: Bool = false // Default to false, will be set during fetch

    // Implement Equatable based on ID
    static func == (lhs: Chat, rhs: Chat) -> Bool {
        lhs.id == rhs.id
    }
    // Implement Hashable based on ID
    func hash(into hasher: inout Hasher) {
         hasher.combine(id)
     }

    // Initializer for combining results
    init(id: Int, requestId: Int?, otherParticipant: Profile, createdAt: Date, lastMessageContent: String? = nil, lastMessageTimestamp: Date? = nil, requestTitle: String? = nil, requestImageUrl: String? = nil, lastMessageSenderId: UUID? = nil, isUnread: Bool = false) {
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
    }
}

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
