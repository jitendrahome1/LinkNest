//
//  SyncService.swift
//  CloudKit lands behind this protocol. The app works local-first;
//  Views never talk to CloudKit directly.
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
}

final class NoopSyncService: SyncService, @unchecked Sendable {
    private(set) var status: SyncStatus = .upToDate(.now)
    func syncNow() async { status = .upToDate(.now) }
}
