//
//  SupabaseClientProvider.swift
//  Single shared SupabaseClient for the app. If SupabaseSecrets.swift is
//  missing (it's gitignored), copy the values from your Supabase
//  project's Settings > API page into that file.
//

import Supabase
import Foundation

enum SupabaseClientProvider {
    static let shared: SupabaseClient = SupabaseClient(
        supabaseURL: URL(string: SupabaseSecrets.projectURL)!,
        supabaseKey: SupabaseSecrets.anonKey
    )
}

/// Realtime's `decodeRecord`/`decodeOldRecord` need an explicit JSONDecoder —
/// unlike PostgREST calls, which use the client's own preconfigured one.
/// Postgres sends timestamptz as ISO-8601 with fractional seconds
/// (e.g. "2026-08-19T10:30:00.123456+00:00").
enum SupabaseRealtimeCoding {
    static let decoder: JSONDecoder = {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let whole = ISO8601DateFormatter()
        whole.formatOptions = [.withInternetDateTime]

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { valueDecoder in
            let container = try valueDecoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = fractional.date(from: string) ?? whole.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        return decoder
    }()
}
