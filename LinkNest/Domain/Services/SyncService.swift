//
//  SyncService.swift
//  Supabase lands behind this protocol (SupabaseSyncService). The app
//  works local-first; Views never talk to Supabase directly.
//

import Foundation

enum SyncStatus: Equatable, Sendable {
    case idle
    case syncing
    case upToDate(Date)
    case failed(String)
}

protocol SyncService: AnyObject, Sendable {
    var status: SyncStatus { get }
    func syncNow() async
    /// Tears down any live subscriptions. Called on sign-out.
    func stop() async
}

final class NoopSyncService: SyncService, @unchecked Sendable {
    private(set) var status: SyncStatus = .upToDate(.now)
    func syncNow() async { status = .upToDate(.now) }
    func stop() async {}
}
