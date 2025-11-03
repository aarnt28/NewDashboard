import Foundation

struct TicketDTO: Codable, Identifiable, Hashable {
    enum Status: String, Codable, CaseIterable {
        case open
        case pending
        case resolved
        case closed
    }

    let id: UUID
    var number: String
    var title: String
    var status: Status
    var clientId: UUID
    var assignee: String?
    var updatedAt: Date
    var createdAt: Date
    var description: String?
    var attachments: [AttachmentDTO]
}

struct ClientDTO: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var email: String?
    var phone: String?
    var updatedAt: Date
    var customAttributes: [String: String]?
}

struct HardwareDTO: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var barcode: String
    var quantityOnHand: Int
    var updatedAt: Date
    var lastInventoryEventAt: Date?
}

struct InventoryEventDTO: Codable, Identifiable, Hashable {
    let id: UUID
    var hardwareId: UUID
    var delta: Int
    var balance: Int
    var note: String?
    var createdAt: Date
    var updatedAt: Date
    var pendingRetry: Bool
}

struct AttachmentDTO: Codable, Identifiable, Hashable {
    let id: UUID
    var fileName: String
    var contentType: String
    var size: Int
    var downloadURL: URL
    var thumbnailURL: URL?
}

struct PagedResponse<Item: Codable>: Codable {
    var items: [Item]
    var nextCursor: String?
}

struct InventoryAdjustmentRequest: Codable {
    let hardwareId: UUID
    let quantity: Int
    let note: String?
    let barcode: String
}
