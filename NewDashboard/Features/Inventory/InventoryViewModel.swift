import Foundation
import SwiftData
import SwiftUI

@MainActor
final class InventoryViewModel: ObservableObject {
    @Published var adjustmentQuantity: Int = 1
    @Published var note: String = ""
    @Published var errorMessage: String?
    @Published var bannerMessage: String?
    @Published var isSubmitting: Bool = false
    @Published var activeHardware: HardwareEntity?

    private let environment: AppEnvironment
    private let context: ModelContext

    init(environment: AppEnvironment, context: ModelContext) {
        self.environment = environment
        self.context = context
    }

    func presentScanner() {
        bannerMessage = nil
        errorMessage = nil
    }

    func handleScan(code: String) {
        guard let hardware = try? context.fetch(FetchDescriptor<HardwareEntity>(predicate: #Predicate { $0.barcode == code })).first else {
            bannerMessage = "No hardware found for barcode \(code)"
            return
        }
        activeHardware = hardware
        adjustmentQuantity = 1
        note = ""
    }

    func submitAdjustment() {
        guard let hardware = activeHardware else { return }
        Task {
            isSubmitting = true
            errorMessage = nil
            let delta = adjustmentQuantity
            let optimisticEvent = InventoryEventEntity(dto: InventoryEventDTO(id: UUID(),
                                                                             hardwareId: hardware.id,
                                                                             delta: delta,
                                                                             balance: hardware.quantityOnHand + delta,
                                                                             note: note.isEmpty ? nil : note,
                                                                             createdAt: Date(),
                                                                             updatedAt: Date(),
                                                                             pendingRetry: true),
                                                       hardware: hardware)
            context.insert(optimisticEvent)
            hardware.quantityOnHand += delta
            try? context.save()

            let request = InventoryAdjustmentRequest(hardwareId: hardware.id,
                                                     quantity: delta,
                                                     note: note.isEmpty ? nil : note,
                                                     barcode: hardware.barcode)
            do {
                let endpoint = Endpoint<InventoryEventDTO>(path: "/api/v1/inventory/adjust",
                                                            method: .post,
                                                            body: try Endpoint.jsonBody(request))
                let response = try await environment.apiClient.send(endpoint)
                if let dto = response.value {
                    let mergedEvent = try ModelMapper.upsert(event: dto, in: context)
                    mergedEvent.pendingRetry = false
                    hardware.quantityOnHand = dto.balance
                    hardware.lastInventoryEventAt = dto.updatedAt
                    try context.save()
                } else {
                    optimisticEvent.pendingRetry = false
                    try context.save()
                }
                try? await environment.syncEngine.sync(.inventoryEvents)
                bannerMessage = "Inventory updated"
            } catch APIError.rateLimited(let retryAfter) {
                await handleFailure(for: hardware, event: optimisticEvent, reason: "Rate limited", retryAfter: retryAfter)
            } catch APIError.server {
                await handleFailure(for: hardware, event: optimisticEvent, reason: "Server error", retryAfter: nil)
            } catch {
                await handleFailure(for: hardware, event: optimisticEvent, reason: error.localizedDescription, retryAfter: nil)
            }
            isSubmitting = false
        }
    }

    private func handleFailure(for hardware: HardwareEntity,
                               event: InventoryEventEntity,
                               reason: String,
                               retryAfter: TimeInterval?) async {
        errorMessage = reason
        event.pendingRetry = true
        let pending = PendingInventoryAdjustmentEntity(hardwareId: hardware.id,
                                                       quantity: event.delta,
                                                       note: event.note,
                                                       lastError: reason)
        context.insert(pending)
        try? context.save()
        if let retryAfter {
            let delay = max(retryAfter, 5)
            bannerMessage = "Retrying in \(Int(delay)) seconds"
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            try? await environment.syncEngine.sync(.inventoryEvents)
        }
    }
}
