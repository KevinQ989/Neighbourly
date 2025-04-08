//
//  DataFetching.swift
//  Neighbourly
//
//  Created by Kevin Quah on 6/4/25.
//
import Foundation
import Supabase
import CoreLocation //If you need it here
import SwiftUI

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
    
    @MainActor
    func fetchMyReviews(
        userId: UUID
    ) async throws -> [Review] {
        let params = ReviewParams(
            my_id: userId
        )
        let fetchedReviews: [Review] = try await self
            .rpc("my_reviews", params: params)
            .select()
            .execute()
            .value
        
        return fetchedReviews
    }
}
