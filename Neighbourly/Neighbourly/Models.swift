// Models.swift
import Foundation

// Profile model
struct Profile: Codable, Identifiable {
    let id: String
    let username: String
    let name: String
    let profilePicture: String?  // Matches the "profile_picture" column in Supabase
    let badges: [String]?        // Matches the badges column (an array of text)
}

// Help Request model
struct HelpRequest: Codable, Identifiable {
    let id: String
    let userId: String       // References profiles.id
    let caption: String?
    let photo: String?       // URL or asset name for the request photo
    let createdAt: Date?     // Matches created_at column in Supabase
}

// Review model
struct Review: Codable, Identifiable {
    let id: String
    let userId: String       // The profile that is being reviewed
    let reviewerId: String   // The id of the reviewer
    let reviewText: String?
    let rating: Int?
    let createdAt: Date?
}
