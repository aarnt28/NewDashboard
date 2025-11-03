import Foundation
import SwiftData

@MainActor
final class SyncMetadataStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func metadata(for key: String) throws -> SyncMetadataEntity {
        if let existing = try context.fetch(FetchDescriptor<SyncMetadataEntity>(predicate: #Predicate { $0.key == key })).first {
            return existing
        }
        let metadata = SyncMetadataEntity(key: key)
        context.insert(metadata)
        return metadata
    }

    func update(_ metadata: SyncMetadataEntity, lastSync: Date?, etag: String?) {
        metadata.lastSuccessfulSync = lastSync
        metadata.etag = etag
        metadata.updatedAt = Date()
    }
}
