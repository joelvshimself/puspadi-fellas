import Foundation
import Supabase

/// Single shared Supabase client for the app. Edge Function callers and the
/// Place Detail Realtime subscription all use this so we don't open multiple
/// anonymous sessions against the same project.
enum SupabaseClientProvider {
    static let shared = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey,
        options: SupabaseClientOptions(
            auth: .init(emitLocalSessionAsInitialSession: true)
        )
    )
}
