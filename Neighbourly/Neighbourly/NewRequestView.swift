//
//  NewRequestView.swift
//  Neighbourly
//
//  Created by Kevin Quah on 21/3/25.
//


//
//  NewRequestView.swift
//  Neighbourly
//
//  Created by Kevin Quah on 21/3/25.
//

import SwiftUI

struct NewRequestView: View {
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var category: String = ""
    @State private var date: Date = Date()
    @State private var location: String = ""
    @State private var images: [UIImage] = []
    
    let categories = ["Moving Help", "Technical Help", "Pet Care", "Groceries"]
    
    var body: some View {
        NavigationView {
            VStack {
                Form {
                    HStack {
                        Text("Title")
                        TextField("Name your request", text: $title)
                    }
                    VStack(alignment: .leading) {
                        Text("Description")
                        TextField("Include more details about your request", text: $description)
                    }
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) {
                            category in Text(category)
                        }
                    }
                    DatePicker("Complete By", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    HStack {
                        Text("Location")
                        TextField("Key in your request address", text: $location)
                    }
                    HStack{
                        Text("Images")
                        Button(action: {
                            print("Image")
                        }) {
                            Text("Add Files")
                                .frame(maxWidth: 80)
                                .padding(5)
                                .background(Color.gray.opacity(0.4))
                                .clipShape(.capsule)
                        }
                    }
                    VStack (alignment: .center){
                        HStack (spacing: 10){
                            Button(action: {
                                title = ""
                                description = ""
                                category = ""
                                date = Date()
                                location = ""
                            }) {
                                Text("Clear")
                                    .frame(maxWidth: 50)
                                    .padding(15)
                                    .background(Color.gray.opacity(0.3))
                                    .clipShape(.capsule)
                            }
                            
                            Button(action: {
                                print("Request submitted")
                            }) {
                                Text("Post Request")
                                    .frame(maxWidth: 130)
                                    .padding(15)
                                    .background(Color.black)
                                    .clipShape(.capsule)
                            }
                        }
                        .padding(.top,10)
                    }
                }
            }
            .navigationTitle("New Request")
        }
    }
}

#Preview {
    NewRequestView()
}
