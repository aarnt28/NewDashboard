import Foundation
import SwiftData

@Model
final class ClientEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var email: String?
    var phone: String?
    var updatedAt: Date
    var customAttributes: [String: String]
    @Relationship(deleteRule: .cascade, inverse: \TicketEntity.client) var tickets: [TicketEntity]

    init(dto: ClientDTO) {
        self.id = dto.id
        self.name = dto.name
        self.email = dto.email
        self.phone = dto.phone
        self.updatedAt = dto.updatedAt
        self.customAttributes = dto.customAttributes ?? [:]
        self.tickets = []
    }
}

@Model
final class TicketEntity {
    @Attribute(.unique) var id: UUID
    var number: String
    var title: String
    var statusRaw: String
    var assignee: String?
    var details: String?
    var createdAt: Date
    var updatedAt: Date
    @Relationship var client: ClientEntity?
    @Relationship(deleteRule: .cascade, inverse: \TicketAttachmentEntity.ticket) var attachments: [TicketAttachmentEntity]

    init(dto: TicketDTO, client: ClientEntity?) {
        self.id = dto.id
        self.number = dto.number
        self.title = dto.title
        self.statusRaw = dto.status.rawValue
        self.assignee = dto.assignee
        self.details = dto.description
        self.createdAt = dto.createdAt
        self.updatedAt = dto.updatedAt
        self.client = client
        self.attachments = dto.attachments.map { TicketAttachmentEntity(dto: $0) }
        for attachment in attachments {
            attachment.ticket = self
        }
    }

    var status: TicketDTO.Status {
        get { TicketDTO.Status(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }
}

@Model
final class TicketAttachmentEntity {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var contentType: String
    var size: Int
    var downloadURL: URL
    var thumbnailURL: URL?
    @Relationship var ticket: TicketEntity?

    init(dto: AttachmentDTO) {
        self.id = dto.id
        self.fileName = dto.fileName
        self.contentType = dto.contentType
        self.size = dto.size
        self.downloadURL = dto.downloadURL
        self.thumbnailURL = dto.thumbnailURL
        self.ticket = nil
    }
}

@Model
final class HardwareEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var barcode: String
    var quantityOnHand: Int
    var updatedAt: Date
    var lastInventoryEventAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \InventoryEventEntity.hardware) var events: [InventoryEventEntity]

    init(dto: HardwareDTO) {
        self.id = dto.id
        self.name = dto.name
        self.barcode = dto.barcode
        self.quantityOnHand = dto.quantityOnHand
        self.updatedAt = dto.updatedAt
        self.lastInventoryEventAt = dto.lastInventoryEventAt
        self.events = []
    }
}

@Model
final class InventoryEventEntity {
    @Attribute(.unique) var id: UUID
    var delta: Int
    var balance: Int
    var note: String?
    var createdAt: Date
    var updatedAt: Date
    var pendingRetry: Bool
    @Relationship var hardware: HardwareEntity?

    init(dto: InventoryEventDTO, hardware: HardwareEntity?) {
        self.id = dto.id
        self.delta = dto.delta
        self.balance = dto.balance
        self.note = dto.note
        self.createdAt = dto.createdAt
        self.updatedAt = dto.updatedAt
        self.pendingRetry = dto.pendingRetry
        self.hardware = hardware
    }
}

@Model
final class SyncMetadataEntity {
    @Attribute(.unique) var key: String
    var lastSuccessfulSync: Date?
    var etag: String?
    var updatedAt: Date

    init(key: String, lastSuccessfulSync: Date? = nil, etag: String? = nil) {
        self.key = key
        self.lastSuccessfulSync = lastSuccessfulSync
        self.etag = etag
        self.updatedAt = Date()
    }
}

@Model
final class PendingInventoryAdjustmentEntity {
    @Attribute(.unique) var id: UUID
    var hardwareId: UUID
    var quantity: Int
    var note: String?
    var createdAt: Date
    var lastError: String?

    init(hardwareId: UUID, quantity: Int, note: String?, lastError: String?) {
        self.id = UUID()
        self.hardwareId = hardwareId
        self.quantity = quantity
        self.note = note
        self.createdAt = Date()
        self.lastError = lastError
    }
}
