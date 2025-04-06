//
//  LocationManager.swift
//  Neighbourly
//
//  Created by Yap Ze Kai on 26/3/25.
//

// LocationManager.swift

import Foundation
import CoreLocation // Import CoreLocation framework
import Combine // Import Combine for ObservableObject

// Make LocationManager conform to NSObject and CLLocationManagerDelegate
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // The core location manager instance
    private let manager = CLLocationManager()

    // Published properties to update SwiftUI views
    @Published var userLocation: CLLocationCoordinate2D? // The user's current coordinates
    @Published var authorizationStatus: CLAuthorizationStatus // The app's location permission status
    @Published var isAuthorized: Bool = false // Convenience bool

    // Singleton pattern for easy access (optional, can also use @StateObject in views)
    static let shared = LocationManager()

    // Private initializer for singleton pattern
    private override init() {
        // Initialize authorizationStatus with the current status
        authorizationStatus = manager.authorizationStatus
        super.init() // Call NSObject's initializer
        manager.delegate = self // Set the delegate to self
        manager.desiredAccuracy = kCLLocationAccuracyReduced // Use reduced accuracy for privacy/battery
        updateAuthorizationStatus() // Update initial authorization state
    }

    // Request permission from the user
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    // Start tracking location updates
    func startUpdatingLocation() {
        // Only start if authorized
        if isAuthorized {
            manager.startUpdatingLocation()
        } else {
            print("LocationManager: Not authorized to start updating location.")
            // Optionally request permission again if status is undetermined
            if authorizationStatus == .notDetermined {
                requestPermission()
            }
        }
    }

    // Stop tracking location updates
    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate Methods

    // This method is called whenever the authorization status changes
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        updateAuthorizationStatus()
        print("LocationManager: Authorization status changed to \(authorizationStatus.rawValue)")

        // If authorized, start updating location
        if isAuthorized {
            startUpdatingLocation()
        } else {
            // Handle cases where permission was denied or restricted
            stopUpdatingLocation() // Stop updates if no longer authorized
            userLocation = nil // Clear location if not authorized
        }
    }

    // This method is called when new location data is available
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Get the latest location's coordinates
        if let location = locations.last?.coordinate {
            // Update the published property only if it has changed significantly (optional)
            // For simplicity, we update it directly here
            userLocation = location
            // print("LocationManager: Updated location - Lat: \(location.latitude), Lon: \(location.longitude)")
            // Often, you only need one location update, so you might stop updates here
            // stopUpdatingLocation()
        }
    }

    // This method is called when location updates fail
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager: Failed to get location - \(error.localizedDescription)")
        // Handle errors appropriately (e.g., show an alert to the user)
    }

    // Helper function to update the isAuthorized flag
    private func updateAuthorizationStatus() {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }
    
    var equatableUserLocation: EquatableCoordinate {
            EquatableCoordinate(coordinate: userLocation)
        }
}
