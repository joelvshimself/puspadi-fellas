import Foundation

/// The anon key is safe to embed in client code by design — Supabase's
/// security model relies on Row Level Security, not on this key being
/// secret. The service_role key and the Google Maps API key are the ones
/// that must never appear here; they only ever live in the Edge Function's
/// environment. See docs/specs.md §5/§6.
enum SupabaseConfig {
    static let url = URL(string: "https://svztcykgmlgjiqfqpimc.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN2enRjeWtnbWxnamlxZnFwaW1jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY0ODM3NzAsImV4cCI6MjEwMjA1OTc3MH0.NMAxUShXELBIURXih5ChTHxHRggEN65kojVVqbDfN7A"

    /// Deep link opened after the user taps the email confirmation link.
    /// Must match Dashboard → Authentication → URL Configuration (Site URL + Redirect URLs).
    static let authRedirectURL = URL(string: "puspadi://auth/callback")!
}
