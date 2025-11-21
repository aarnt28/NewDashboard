import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - API Error

struct APIError: Error, LocalizedError, Codable {
    let detail: String?
    var errorDescription: String? { detail ?? "Unknown server error" }
}

// MARK: - EntryType

enum EntryType: String, Codable, CaseIterable, Identifiable {
    case time
    case hardware
    case deployment_flat_rate
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .time: return "Time"
        case .hardware: return "Hardware"
        case .deployment_flat_rate: return "Deployment Flat Rate"
        }
    }
}

// MARK: - Ticket Attachment

struct TicketAttachment: Codable, Identifiable, Equatable {
    let id: String
    let filename: String
    let content_type: String?
    let size: Int?
    let uploaded_at: String
    let url: String?
}

// MARK: - IntBool (0/1 ? Bool)

@propertyWrapper
struct IntBool: Codable {
    var wrappedValue: Bool
    init(wrappedValue: Bool) { self.wrappedValue = wrappedValue }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { wrappedValue = (i != 0) }
        else if let b = try? c.decode(Bool.self) { wrappedValue = b }
        else { wrappedValue = false }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(wrappedValue ? 1 : 0)
    }
}

// MARK: - Ticket

struct Ticket: Codable, Identifiable, Equatable {
    let id: Int
    var client: String?
    var client_key: String
    var start_iso: String
    var end_iso: String?
    var elapsed_minutes: Int?
    var rounded_minutes: Int?
    var rounded_hours: String?
    var note: String?
    @IntBool var completed: Bool
    @IntBool var sent: Bool
    var invoice_number: String?
    var invoiced_total: String?
    var created_at: String?
    var minutes: Int?
    var entry_type: EntryType
    var hardware_id: Int?
    var hardware_barcode: String?
    var hardware_description: String?
    var hardware_sales_price: String?
    var hardware_quantity: Int?
    var flat_rate_amount: String?
    var flat_rate_quantity: Int?
    var calculated_value: String?
    var attachments: [TicketAttachment] = []
    
    static func == (lhs: Ticket, rhs: Ticket) -> Bool { lhs.id == rhs.id }
    
    var startDate: Date {
        get { ISO8601DateTransformer.parse(start_iso) ?? Date() }
        set { start_iso = ISO8601DateTransformer.string(newValue) }
    }
    var endDate: Date? {
        get { end_iso.flatMap { ISO8601DateTransformer.parse($0) } }
        set { end_iso = newValue.map { ISO8601DateTransformer.string($0) } }
    }
}

struct NewTicket: Codable {
    var client_key: String
    var entry_type: EntryType = .time
    var start_iso: String
    var end_iso: String?
    var note: String?
    var invoice_number: String?
    var sent: Int?
    var completed: Int?
    var hardware_id: Int?
    var hardware_barcode: String?
    var hardware_quantity: Int?
    var hardware_description: String?
    var hardware_sales_price: String?
    var flat_rate_amount: String?
    var flat_rate_quantity: Int?
    var invoiced_total: String?
}

// MARK: - Clients

enum ClientAttributeKeyboard: String, Codable, CaseIterable {
    case plain
    case name
    case email
    case phone
    case number
    case decimal
    case url
    case location

#if canImport(UIKit)
    var textContentType: UITextContentType? {
        switch self {
        case .email: return .emailAddress
        case .phone: return .telephoneNumber
        case .url: return .URL
        case .name: return .name
        default: return nil
        }
    }
#endif

    var autocapitalization: TextInputAutocapitalization {
        switch self {
        case .name, .location: return .words
        default: return .never
        }
    }

    var keyboardType: UIKeyboardType {
        switch self {
        case .email: return .emailAddress
        case .phone: return .phonePad
        case .number: return .numberPad
        case .decimal: return .decimalPad
        case .url: return .URL
        default: return .default
        }
    }

    static func suggested(for key: String) -> ClientAttributeKeyboard {
        let lower = key.lowercased()
        if lower.contains("email") { return .email }
        if lower.contains("phone") || lower.contains("tel") { return .phone }
        if lower.contains("zip") || lower.contains("postal") { return .number }
        if lower.contains("rate") || lower.contains("amount") || lower.contains("price") || lower.contains("cost") { return .decimal }
        if lower.contains("url") || lower.contains("website") { return .url }
        if lower.contains("address") || lower.contains("city") || lower.contains("state") { return .location }
        if lower.contains("name") || lower.contains("contact") { return .name }
        return .plain
    }
}

struct ClientAttributeKey: Identifiable, Codable, Hashable {
    let key: String
    let keyboard: ClientAttributeKeyboard
    var id: String { key }

    init(key: String, keyboard: ClientAttributeKeyboard = .plain) {
        self.key = key
        self.keyboard = keyboard
    }

    init(from decoder: Decoder) throws {
        if let sv = try? decoder.singleValueContainer(), let string = try? sv.decode(String.self) {
            self.key = string
            self.keyboard = .plain
            return
        }

        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try c.decode(String.self, forKey: .key)
        self.keyboard = try c.decodeIfPresent(ClientAttributeKeyboard.self, forKey: .keyboard) ?? .plain
    }

    private enum CodingKeys: String, CodingKey { case key, keyboard }
}

struct ClientAttribute: Identifiable, Codable, Hashable {
    let key: String
    var value: String
    var keyboard: ClientAttributeKeyboard
    var id: String { key }
}

// Flat model for UI
struct ClientRecord: Identifiable, Codable, Hashable {
    let client_key: String
    let name: String
    let attributes: [ClientAttribute]?
    var id: String { client_key }

    var attributeDictionary: [String: String] {
        let pairs = attributes?.map { ($0.key, $0.value) } ?? []
        return Dictionary(uniqueKeysWithValues: pairs)
    }
}

// Envelope for GET /api/v1/clients
struct ClientsEnvelope: Decodable {
    let clients: [String: ClientBlob]
    let attribute_keys: [ClientAttributeKey]?

    struct ClientBlob: Decodable {
        let name: String
        let extras: [String: String]

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: DynamicCodingKey.self)
            var nameVal = ""
            var extrasDict: [String: String] = [:]

            for key in c.allKeys {
                if key.stringValue == "name" {
                    nameVal = (try? c.decode(String.self, forKey: key)) ?? ""
                } else {
                    if let s = try? c.decode(String.self, forKey: key) { extrasDict[key.stringValue] = s }
                    else if let i = try? c.decode(Int.self, forKey: key) { extrasDict[key.stringValue] = String(i) }
                    else if let d = try? c.decode(Double.self, forKey: key) { extrasDict[key.stringValue] = String(d) }
                    else if let b = try? c.decode(Bool.self, forKey: key) { extrasDict[key.stringValue] = String(b) }
                    else if (try? c.decodeNil(forKey: key)) == true { extrasDict[key.stringValue] = "—" }
                }
            }
            name = nameVal
            extras = extrasDict
        }

        private struct DynamicCodingKey: CodingKey {
            var stringValue: String
            init?(stringValue: String) { self.stringValue = stringValue }
            var intValue: Int? { nil }
            init?(intValue: Int) { nil }
        }
    }
}

// MARK: - Hardware

struct Hardware: Codable, Identifiable, Hashable {
    let id: Int
    let barcode: String
    let description: String
    let acquisition_cost: String?
    let sales_price: String?
    let created_at: String?
    let common_vendors: [String]?
    let average_unit_cost: Double?
    // Optional inventory status fields; server may or may not provide these
    let quantity_on_hand: Int?
    let quantity_available: Int?
    let quantity_reserved: Int?
    let quantity_committed: Int?
}

/// A forgiving /hardware wrapper that accepts:
struct HardwareResult: Decodable {
    let items: [Hardware]
    let total: Int?
    
    private enum CodingKeys: String, CodingKey { case items, total }
    
    init(from decoder: Decoder) throws {
        if let c = try? decoder.container(keyedBy: CodingKeys.self),
           let arr = try? c.decode([Hardware].self, forKey: .items) {
            self.items = arr
            self.total = try? c.decode(Int.self, forKey: .total)
            return
        }
        let sv = try decoder.singleValueContainer()
        if let arr = try? sv.decode([Hardware].self) {
            self.items = arr
            self.total = arr.count
            return
        }
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unrecognized hardware payload"))
    }
}

// MARK: - ISO8601 helpers

enum ISO8601DateTransformer {
    private static let encoder: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let decoder: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static func string(_ date: Date) -> String { encoder.string(from: date) }
    static func parse(_ string: String) -> Date? {
        if let d = decoder.date(from: string) { return d }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: string)
    }
}
//
//  Models.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//


