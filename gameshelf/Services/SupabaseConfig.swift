//
//  SupabaseConfig.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-27.
//

import Foundation

enum SupabaseConfig: Sendable {
    static let defaultBaseURL = "https://dgsifbugyepnzxvcfaax.supabase.co"

    static var baseURLString: String {
        if let stored = UserDefaults.standard.string(forKey: "supabase_base_url"),
           !stored.contains("127.0.0.1"), !stored.contains("localhost"), !stored.isEmpty {
            return stored
        }
        return defaultBaseURL
    }

    static let defaultAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnc2lmYnVneWVwbnp4dmNmYWF4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc3ODE2NTAsImV4cCI6MjEwMzM1NzY1MH0.UxUY0jLBZh136iuAu5p6Dp8w_e_aIs2BFu0_ERfkZNw"

    static var anonKey: String {
        if let stored = UserDefaults.standard.string(forKey: "supabase_anon_key"),
           !stored.hasSuffix(".dummy"), !stored.contains("supabase-demo"), !stored.isEmpty {
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
