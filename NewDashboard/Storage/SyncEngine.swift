import Foundation
import SwiftData
import os

@MainActor
final class SyncEngine: ObservableObject {
    enum Entity: String, CaseIterable {
        case tickets
        case clients
        case hardware
        case inventoryEvents
    }

    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastSyncDates: [Entity: Date] = [:]

    private let apiClient: APIClient
    private let context: ModelContext
    private let metadataStore: SyncMetadataStore
    private let telemetry: Telemetry
    private let logger: Logger
    private var retryBackoff = ExponentialBackoff(base: 2, maxDelay: 15 * 60)

    init(apiClient: APIClient, context: ModelContext, telemetry: Telemetry) {
        self.apiClient = apiClient
        self.context = context
        self.metadataStore = SyncMetadataStore(context: context)
        self.telemetry = telemetry
        self.logger = telemetry.logger(for: .sync)
    }

    func syncAll() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for entity in Entity.allCases {
                    group.addTask { try await self.sync(entity) }
                }
                try await group.waitForAll()
            }
            lastError = nil
        } catch {
            logger.error("Sync failed: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    func sync(_ entity: Entity) async throws {
        switch entity {
        case .tickets:
            try await performSync(entity: entity, path: "/api/v1/tickets") { dto in
                try ModelMapper.upsert(ticket: dto, in: context)
                return dto.updatedAt
            }
        case .clients:
            try await performSync(entity: entity, path: "/api/v1/clients") { dto in
                try ModelMapper.upsert(client: dto, in: context)
                return dto.updatedAt
            }
        case .hardware:
            try await performSync(entity: entity, path: "/api/v1/hardware") { dto in
                try ModelMapper.upsert(hardware: dto, in: context)
                return dto.updatedAt
            }
        case .inventoryEvents:
            try await performSync(entity: entity, path: "/api/v1/inventory/events") { dto in
                try ModelMapper.upsert(event: dto, in: context)
                return dto.updatedAt
            }
        }
    }

    private func performSync<DTO: Codable>(entity: Entity,
                                           path: String,
                                           merge: @escaping (DTO) throws -> Date) async throws {
        let metadata = try metadataStore.metadata(for: entity.rawValue)
        var nextCursor: String?
        var newestUpdate = metadata.lastSuccessfulSync
        var page = 1

        repeat {
            var query: [URLQueryItem] = [
                URLQueryItem(name: "limit", value: "200"),
                URLQueryItem(name: "page", value: String(page))
            ]
            if let since = metadata.lastSuccessfulSync {
                query.append(URLQueryItem(name: "updated_since", value: ISO8601DateFormatter().string(from: since)))
            }
            if let cursor = nextCursor {
                query.append(URLQueryItem(name: "cursor", value: cursor))
            }

            var headers: [String: String] = [:]
            if metadata.lastSuccessfulSync != nil, let etag = metadata.etag, page == 1 {
                headers["If-None-Match"] = etag
            }

            let endpoint = Endpoint<PagedResponse<DTO>>(path: path, queryItems: query, headers: headers)

            do {
                let response = try await apiClient.send(endpoint)
                if response.statusCode == 304 {
                    logger.debug("304 Not Modified for \(entity.rawValue) — skipping merge")
                    metadataStore.update(metadata, lastSync: metadata.lastSuccessfulSync, etag: response.etag ?? metadata.etag)
                    newestUpdate = metadata.lastSuccessfulSync
                    break
                }
                guard let payload = response.value else { break }
                var highest = newestUpdate
                for item in payload.items {
                    let updatedAt = try merge(item)
                    highest = max(highest ?? updatedAt, updatedAt)
                }
                if context.hasChanges {
                    try context.save()
                }
                newestUpdate = highest
                metadataStore.update(metadata, lastSync: newestUpdate, etag: response.etag ?? metadata.etag)
                nextCursor = payload.nextCursor
                page += 1
                if payload.items.isEmpty {
                    break
                }
            } catch APIError.rateLimited(let retryAfter) {
                let delay = retryAfter ?? retryBackoff.nextDelay()
                logger.warning("Rate limited for \(entity.rawValue). Retrying in \(delay) seconds")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                continue
            } catch APIError.server {
                let delay = retryBackoff.nextDelay()
                logger.error("Server error syncing \(entity.rawValue). Retrying in \(delay) seconds")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                continue
            } catch {
                throw error
            }
        } while nextCursor != nil

        if let newestUpdate {
            lastSyncDates[entity] = newestUpdate
            retryBackoff.reset()
        }
    }
}

struct ExponentialBackoff {
    private let base: Double
    private let maxDelay: Double
    private var attempt: Int = 0

    init(base: Double, maxDelay: Double) {
        self.base = base
        self.maxDelay = maxDelay
    }

    mutating func nextDelay() -> Double {
        attempt += 1
        let delay = min(pow(base, Double(attempt)), maxDelay)
        return delay
    }

    mutating func reset() {
        attempt = 0
    }
}
