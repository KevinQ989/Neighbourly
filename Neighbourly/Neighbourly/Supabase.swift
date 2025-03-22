//
//  Supabase.swift
//  Neighbourly
//
//  Created by Kevin Quah on 22/3/25.
//

import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://ydvhcbmbfnaioyckoqzw.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlkdmhjYm1iZm5haW95Y2tvcXp3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI2MDQxNTAsImV4cCI6MjA1ODE4MDE1MH0.eJg_J-1XbqsYzkfzJuo7XM2XBf7EWYca5V1RtSX9FXo"
)
