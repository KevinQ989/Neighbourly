//
//  Homepage.swift
//  Neighbourly
//
//  Created by Yap Ze Kai on 20/3/25.
//
import SwiftUI
import MapKit

struct HomePageView: View {
    @State private var searchText = ""
    @State private var selectedCategory: String?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198), // Singapore coordinates as default
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    // Sample data for categories
    let categories = [
        Category(name: "Moving Help", imageName: "moving_help"),
        Category(name: "Tech", imageName: "tech"),
        Category(name: "Groceries", imageName: "groceries"),
        Category(name: "Pet Care", imageName: "pet_care"),
        Category(name: "Home Repair", imageName: "home_repair")
    ]
    
    // Sample data for nearby requests
    let nearbyRequests = [
        Request(id: 1, userName: "Daren Tan", description: "Help me move my sofa", imageName: "sofa_image"),
        Request(id: 2, userName: "Ng Jun Ying", description: "Take care of my cat", imageName: "cat_image"),
        Request(id: 3, userName: "Esther K", description: "Tech support needed", imageName: "tech_support")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search", text: $searchText)
                        .font(.system(size: 17))
                }
                .padding(10)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Categories section
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Categories")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 20) {
                                    ForEach(categories) { category in
                                        CategoryView(category: category)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 5)
                            }
                        }
                        
                        // Nearby Requests section
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Nearby Requests")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(nearbyRequests) { request in
                                        RequestCard(request: request)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Map section
                        VStack(alignment: .leading) {
                            Text("Map")
                                .font(.headline)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            Map(coordinateRegion: $region, showsUserLocation: true)
                                .frame(height: 200)
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                
                // Tab bar
                CustomTabBar()
            }
            .navigationBarHidden(true)
        }
    }
}

// Category view
struct CategoryView: View {
    let category: Category
    
    var body: some View {
        VStack {
            Image(category.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 70, height: 70)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            
            Text(category.name)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .frame(width: 80)
    }
}

// Request card
struct RequestCard: View {
    let request: Request
    
    var body: some View {
        VStack(alignment: .leading) {
            Image(request.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 140, height: 140)
                .cornerRadius(10)
                .clipped()
            
            Text(request.userName)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(request.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 140)
    }
}

// Custom tab bar
struct CustomTabBar: View {
    var body: some View {
        HStack {
            ForEach(["house.fill", "plus.circle.fill", "bell.fill", "person.fill"], id: \.self) { icon in
                Spacer()
                Button(action: {
                    // Handle tab selection
                }) {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(icon == "house.fill" ? .black : .gray)
                }
                Spacer()
            }
        }
        .padding(.vertical, 10)
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .top
        )
    }
}

// Data models
struct Category: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String
}

struct Request: Identifiable {
    let id: Int
    let userName: String
    let description: String
    let imageName: String
}

// Preview
struct HomePageView_Previews: PreviewProvider {
    static var previews: some View {
        HomePageView()
    }
}

