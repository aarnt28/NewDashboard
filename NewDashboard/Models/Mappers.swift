import Foundation
import SwiftData

enum ModelMapper {
    static func upsert(client dto: ClientDTO, in context: ModelContext) throws -> ClientEntity {
        if let existing = try fetch(ClientEntity.self, id: dto.id, in: context) {
            existing.name = dto.name
            existing.email = dto.email
            existing.phone = dto.phone
            existing.updatedAt = dto.updatedAt
            existing.customAttributes = dto.customAttributes ?? [:]
            return existing
        } else {
            let entity = ClientEntity(dto: dto)
            context.insert(entity)
            return entity
        }
    }

    static func upsert(ticket dto: TicketDTO, in context: ModelContext) throws -> TicketEntity {
        let client = try fetch(ClientEntity.self, id: dto.clientId, in: context)
        let ticket = try fetch(TicketEntity.self, id: dto.id, in: context) ?? TicketEntity(dto: dto, client: client)
        ticket.number = dto.number
        ticket.title = dto.title
        ticket.status = dto.status
        ticket.assignee = dto.assignee
        ticket.details = dto.description
        ticket.updatedAt = dto.updatedAt
        ticket.client = client

        // Attachments
        let existingAttachments = Dictionary(uniqueKeysWithValues: ticket.attachments.map { ($0.id, $0) })
        var newAttachments: [TicketAttachmentEntity] = []
        for attachmentDTO in dto.attachments {
            if let existing = existingAttachments[attachmentDTO.id] {
                existing.fileName = attachmentDTO.fileName
                existing.contentType = attachmentDTO.contentType
                existing.size = attachmentDTO.size
                existing.downloadURL = attachmentDTO.downloadURL
                existing.thumbnailURL = attachmentDTO.thumbnailURL
                existing.ticket = ticket
                newAttachments.append(existing)
            } else {
                let attachment = TicketAttachmentEntity(dto: attachmentDTO)
                attachment.ticket = ticket
                newAttachments.append(attachment)
            }
        }
        ticket.attachments = newAttachments
        return ticket
    }

    static func upsert(hardware dto: HardwareDTO, in context: ModelContext) throws -> HardwareEntity {
        if let entity = try fetch(HardwareEntity.self, id: dto.id, in: context) {
            entity.name = dto.name
            entity.barcode = dto.barcode
            entity.quantityOnHand = dto.quantityOnHand
            entity.updatedAt = dto.updatedAt
            entity.lastInventoryEventAt = dto.lastInventoryEventAt
            return entity
        } else {
            let entity = HardwareEntity(dto: dto)
            context.insert(entity)
            return entity
        }
    }

    static func upsert(event dto: InventoryEventDTO, in context: ModelContext) throws -> InventoryEventEntity {
        let hardware = try fetch(HardwareEntity.self, id: dto.hardwareId, in: context)
        let entity = try fetch(InventoryEventEntity.self, id: dto.id, in: context) ?? InventoryEventEntity(dto: dto, hardware: hardware)
        entity.delta = dto.delta
        entity.balance = dto.balance
        entity.note = dto.note
        entity.createdAt = dto.createdAt
        entity.updatedAt = dto.updatedAt
        entity.pendingRetry = dto.pendingRetry
        entity.hardware = hardware
        if let hardware {
            hardware.lastInventoryEventAt = max(hardware.lastInventoryEventAt ?? .distantPast, dto.updatedAt)
        }
        return entity
}

static func fetch<Entity: PersistentModel>(_ type: Entity.Type, id: UUID, in context: ModelContext) throws -> Entity? {
    let descriptor = FetchDescriptor<Entity>(predicate: #Predicate { $0.id == id })
    return try context.fetch(descriptor).first
}
}

extension TicketEntity {
    func toDTO() -> TicketDTO {
        TicketDTO(id: id,
                  number: number,
                  title: title,
                  status: status,
                  clientId: client?.id ?? UUID(),
                  assignee: assignee,
                  updatedAt: updatedAt,
                  createdAt: createdAt,
                  description: details,
                  attachments: attachments.map { $0.toDTO() })
    }
}

extension TicketAttachmentEntity {
    func toDTO() -> AttachmentDTO {
        AttachmentDTO(id: id,
                      fileName: fileName,
                      contentType: contentType,
                      size: size,
                      downloadURL: downloadURL,
                      thumbnailURL: thumbnailURL)
    }
}

extension ClientEntity {
    func toDTO() -> ClientDTO {
        ClientDTO(id: id,
                  name: name,
                  email: email,
                  phone: phone,
                  updatedAt: updatedAt,
                  customAttributes: customAttributes)
    }
}

extension HardwareEntity {
    func toDTO() -> HardwareDTO {
        HardwareDTO(id: id,
                    name: name,
                    barcode: barcode,
                    quantityOnHand: quantityOnHand,
                    updatedAt: updatedAt,
                    lastInventoryEventAt: lastInventoryEventAt)
    }
}

extension InventoryEventEntity {
    func toDTO() -> InventoryEventDTO {
        InventoryEventDTO(id: id,
                          hardwareId: hardware?.id ?? UUID(),
                          delta: delta,
                          balance: balance,
                          note: note,
                          createdAt: createdAt,
                          updatedAt: updatedAt,
                          pendingRetry: pendingRetry)
    }
}
