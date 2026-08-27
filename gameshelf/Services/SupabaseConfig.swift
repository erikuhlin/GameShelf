//
//  SupabaseConfig.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-27.
//

import Foundation

enum SupabaseConfig: Sendable {
    // Supabase Cloud Project URL
    static var baseURLString: String {
        UserDefaults.standard.string(forKey: "supabase_base_url") ?? "https://dgsifbugyepnzxvcfaax.supabase.co"
    }

    static let defaultAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnc2lmYnVneWVwbnp4dmNmYWF4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc3ODE2NTAsImV4cCI6MjEwMzM1NzY1MH0.UxUY0jLBZh136iuAu5p6Dp8w_e_aIs2BFu0_ERfkZNw"

    static var anonKey: String {
        let stored = UserDefaults.standard.string(forKey: "supabase_anon_key")
        if let stored = stored, !stored.hasSuffix(".dummy") {
            return stored
        }
        return defaultAnonKey
    }

    static var isSyncEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "supabase_sync_enabled") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "supabase_sync_enabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "supabase_sync_enabled")
        }
    }
}
