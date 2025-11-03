import SwiftUI
import SwiftData

struct HardwareDetailView: View {
    @ObservedObject var hardware: HardwareEntity
    @Query private var events: [InventoryEventEntity]

    init(hardware: HardwareEntity) {
        self.hardware = hardware
        let hardwareID = hardware.id
        _events = Query(filter: #Predicate { $0.hardware?.id == hardwareID },
                        sort: [SortDescriptor(\InventoryEventEntity.createdAt, order: .reverse)])
    }

    var body: some View {
        List {
            Section("Overview") {
                LabeledContent("Name") { Text(hardware.name) }
                LabeledContent("Barcode") { Text(hardware.barcode) }
                LabeledContent("On Hand") {
                    Text("\(hardware.quantityOnHand)")
                        .monospacedDigit()
                }
                if let last = hardware.lastInventoryEventAt {
                    LabeledContent("Last Event") {
                        Text(last, style: .relative)
                    }
                }
            }

            Section("Activity") {
                if events.isEmpty {
                    Text("No inventory events yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(events, id: \.id) { event in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%@%d", event.delta >= 0 ? "+" : "", event.delta))
                                    .font(.headline)
                                    .foregroundStyle(event.delta >= 0 ? .green : .red)
                                    .monospacedDigit()
                            }
                            if let note = event.note {
                                Text(note)
                                    .font(.subheadline)
                            }
                            HStack {
                                Label("Balance", systemImage: "scalemass")
                                Spacer()
                                Text("\(event.balance)")
                                    .monospacedDigit()
                                    .font(.callout)
                            }
                            if event.pendingRetry {
                                Text("Pending retry")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle(hardware.name)
    }
}
