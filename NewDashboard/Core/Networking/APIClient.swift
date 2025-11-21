//
//  APIClient.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//


import Foundation
import Combine
import OSLog
import WidgetKit

// MARK: - API Client

final class APIClient: ObservableObject {
    private static var sharedSuite: UserDefaults {
        UserDefaults(suiteName: SharedAppConstants.appGroupSuite) ?? .standard
    }

    private func setShared(_ value: Any?, forKey key: String) {
        let suite = APIClient.sharedSuite
        suite.set(value, forKey: key)
        UserDefaults.standard.set(value, forKey: key)
    }

    private enum Defaults {
        static let baseURL = "APIClient.baseURL"
        static let apiKey = "APIClient.apiKey"
    }

    @Published var baseURL: URL {
        didSet {
            setShared(baseURL.absoluteString, forKey: Defaults.baseURL)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    @Published var apiKey: String {
        didSet {
            setShared(apiKey, forKey: Defaults.apiKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    @Published private(set) var clientAttributeKeys: [ClientAttributeKey] = []
    let urlSession: URLSession

    init(
        baseURL: URL = URL(string: "https://tracker.turnernet.co")!,
        apiKey: String = "CaRpoauTdDYdxQwWhWeXUQy",
        urlSession: URLSession = .shared
    ) {
        let defaults = APIClient.sharedSuite
        if let storedURL = defaults.string(forKey: Defaults.baseURL),
           let url = URL(string: storedURL) {
            self.baseURL = url
        } else {
            self.baseURL = baseURL
        }

        if let storedKey = defaults.string(forKey: Defaults.apiKey) {
            self.apiKey = storedKey
        } else {
            self.apiKey = apiKey
        }

        self.urlSession = urlSession

        // Persist into App Group so the widget can read settings
        setShared(self.baseURL.absoluteString, forKey: Defaults.baseURL)
        setShared(self.apiKey, forKey: Defaults.apiKey)
    }
}

// MARK: - Logging

private let apiLog = Logger(subsystem: "VIPDashboard", category: "API")

// MARK: - Core

private extension APIClient {
    func makeRequest(
        _ path: String,
        method: String = "GET",
        query: [URLQueryItem]? = nil,
        body: Data? = nil,
        contentType: String? = nil
    ) throws -> URLRequest {
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        var comps = URLComponents(url: baseURL.appendingPathComponent(trimmed), resolvingAgainstBaseURL: false)!
        if let query { comps.queryItems = query }
        guard let finalURL = comps.url else { throw URLError(.badURL) }

        var req = URLRequest(url: finalURL)
        req.httpMethod = method

        if !apiKey.isEmpty { req.addValue(apiKey, forHTTPHeaderField: "X-API-Key") }
        req.addValue("application/json", forHTTPHeaderField: "Accept")

        let decidedContentType = contentType ?? (body != nil ? "application/json" : nil)
        if let decidedContentType { req.addValue(decidedContentType, forHTTPHeaderField: "Content-Type") }

        req.httpBody = body
        return req
    }

    func send<T: Decodable>(_ req: URLRequest, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        let (data, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        apiLog.debug("HTTP \(http.statusCode) \(req.httpMethod ?? "GET") \(req.url?.absoluteString ?? "<nil>") bytes=\(data.count)")

        guard (200..<300).contains(http.statusCode) else {
            if let apiErr = try? JSONDecoder().decode(APIError.self, from: data) {
                apiLog.error("API error: \(String(describing: apiErr), privacy: .public)")
                throw apiErr
            }
            let body = String(data: data.prefix(2048), encoding: .utf8) ?? "<non-utf8>"
            apiLog.error("HTTP \(http.statusCode) body=\(body, privacy: .public)")
            throw URLError(.init(rawValue: http.statusCode))
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let body = String(data: data.prefix(2048), encoding: .utf8) ?? "<non-utf8>"
            apiLog.error("Decoding failed: \(String(describing: error), privacy: .public)\nBody: \(body, privacy: .public)")
            throw error
        }
    }
}

// MARK: - Tickets

extension APIClient {
    func listTickets() async throws -> [Ticket] {
        let req = try makeRequest("/api/v1/tickets")
        return try await send(req)
    }

    func listActiveTickets(clientKey: String? = nil) async throws -> [Ticket] {
        var items: [URLQueryItem]? = nil
        if let k = clientKey, !k.isEmpty { items = [URLQueryItem(name: "client_key", value: k)] }
        let req = try makeRequest("/api/v1/tickets/active", query: items)
        return try await send(req)
    }

    func createTicket(_ new: NewTicket) async throws -> Ticket {
        let body = try JSONEncoder().encode(new)
        let req = try makeRequest("/api/v1/tickets", method: "POST", body: body)
        let ticket: Ticket = try await send(req)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedAppConstants.openTicketsWidgetKind)
        return ticket
    }

    func updateTicket(id: Int, patch: [String: Any]) async throws -> Ticket {
        let body = try JSONSerialization.data(withJSONObject: patch, options: [])
        let req = try makeRequest("/api/v1/tickets/\(id)", method: "PATCH", body: body)
        let ticket: Ticket = try await send(req)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedAppConstants.openTicketsWidgetKind)
        return ticket
    }

    func deleteTicket(id: Int) async throws {
        let req = try makeRequest("/api/v1/tickets/\(id)", method: "DELETE")
        let (_, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: SharedAppConstants.openTicketsWidgetKind)
    }
}

// MARK: - Clients

extension APIClient {
    /// GET /api/v1/clients returns:
    func fetchClientsFlat() async throws -> [ClientRecord] {
        let req = try makeRequest("/api/v1/clients")
        let (data, resp) = try await urlSession.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        apiLog.debug("GET /api/v1/clients status=\(code, privacy: .public) bytes=\(data.count)")

        guard (200..<300).contains(code) else {
            let body = String(data: data.prefix(2048), encoding: .utf8) ?? "<non-utf8>"
            apiLog.error("HTTP \(code) /clients body=\(body, privacy: .public)")
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys

        let env: ClientsEnvelope
        do {
            env = try decoder.decode(ClientsEnvelope.self, from: data)
        } catch {
            let body = String(data: data.prefix(2048), encoding: .utf8) ?? "<non-utf8>"
            apiLog.error("Decoding /clients failed: \(String(describing: error), privacy: .public)\nBody: \(body, privacy: .public)")
            throw error
        }

        await MainActor.run {
            clientAttributeKeys = env.attribute_keys ?? []
        }

        let flat = env.clients.map { (key, blob) in
            ClientRecord(
                client_key: key,
                name: blob.name,
                attributes: makeAttributes(from: blob.extras)
            )
        }

        apiLog.debug("Decoded clients count=\(flat.count, privacy: .public)")
        return flat.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

extension APIClient {
    /// PATCH /api/v1/clients/{client_key}
    /// Body: partial object of fields to change (use NSNull() to clear).
    func updateClient(clientKey: String, patch: [String: Any]) async throws -> ClientRecord {
        let body = try JSONSerialization.data(withJSONObject: patch, options: [])
        let req = try makeRequest("/api/v1/clients/\(clientKey)", method: "PATCH", body: body)
        // Server returns one client object; decode into a temp dictionary, then flatten.
        let decoder = JSONDecoder()
        let (data, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // The single-client route in your webapp returns { "client_key": "...", "client": { ... } }
        // BUT other implementations return a flat object. Support both.
        struct SingleEnvelope: Decodable {
            let client_key: String
            let client: [String:String]?
            let name: String?
        }
        
        if let env = try? decoder.decode(SingleEnvelope.self, from: data) {
            let name = env.name ?? env.client?["name"] ?? env.client_key
            let attrs = env.client?.filter { $0.key != "name" } ?? [:]
            return ClientRecord(client_key: env.client_key, name: name, attributes: makeAttributes(from: attrs))
        }

        // Fallback: assume flat map object { "name": "...", other attrs... }
        if let flat = try? decoder.decode([String:String].self, from: data) {
            let name = flat["name"] ?? clientKey
            let attrs = flat.filter { $0.key != "name" }
            return ClientRecord(client_key: clientKey, name: name, attributes: makeAttributes(from: attrs))
        }
        
        // As a last resort try the same shape as list
        if let blob = try? decoder.decode(ClientsEnvelope.ClientBlob.self, from: data) {
            let attrs = blob.extras.filter { $0.key != "name" }
            return ClientRecord(client_key: clientKey, name: blob.name, attributes: makeAttributes(from: attrs))
        }
        
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unrecognized client PATCH response"))
    }
}

// MARK: - Client helpers

private extension APIClient {
    func makeAttributes(from raw: [String: String]) -> [ClientAttribute]? {
        guard !raw.isEmpty else { return nil }

        let hints = Dictionary(uniqueKeysWithValues: clientAttributeKeys.map { ($0.key.lowercased(), $0.keyboard) })
        let attributes = raw.map { key, value in
            let hint = hints[key.lowercased()] ?? ClientAttributeKeyboard.suggested(for: key)
            return ClientAttribute(key: key, value: value, keyboard: hint)
        }

        let sorted = attributes.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
        return sorted.isEmpty ? nil : sorted
    }
}

extension APIClient {
    func keyboardHint(forAttribute key: String) -> ClientAttributeKeyboard {
        if let hint = clientAttributeKeys.first(where: { $0.key.caseInsensitiveCompare(key) == .orderedSame })?.keyboard {
            return hint
        }
        return ClientAttributeKeyboard.suggested(for: key)
    }
}

// MARK: - Hardware

extension APIClient {
    func listHardware(limit: Int = 100, offset: Int = 0) async throws -> HardwareResult {
        let q = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        let req = try makeRequest("/api/v1/hardware", query: q)
        return try await send(req)
    }
}

extension APIClient {
    /// PATCH /api/v1/hardware/{id}
    func updateHardware(id: Int, patch: [String: Any]) async throws -> Hardware {
        let body = try JSONSerialization.data(withJSONObject: patch, options: [])
        let req = try makeRequest("/api/v1/hardware/\(id)", method: "PATCH", body: body)
        return try await send(req)
    }
}


// MARK: - Ticket helpers

extension APIClient {
    func markCompleted(_ ticket: Ticket, completed: Bool) async throws -> Ticket {
        try await updateTicket(id: ticket.id, patch: ["completed": completed ? 1 : 0])
    }

    func markSent(_ ticket: Ticket, sent: Bool, invoice: String?) async throws -> Ticket {
        var p: [String: Any] = ["sent": sent ? 1 : 0]
        if let invoice { p["invoice_number"] = invoice }
        return try await updateTicket(id: ticket.id, patch: p)
    }

    func stopNow(_ ticket: Ticket) async throws -> Ticket {
        try await updateTicket(id: ticket.id, patch: ["end_iso": ISO8601DateTransformer.string(Date())])
    }

    func startNew(clientKey: String, type: EntryType) async throws -> Ticket {
        var payload = NewTicket(
            client_key: clientKey,
            entry_type: type,
            start_iso: ISO8601DateTransformer.string(Date()),
            end_iso: nil,
            note: nil,
            invoice_number: nil,
            sent: 0,
            completed: 0,
            hardware_id: nil,
            hardware_barcode: nil,
            hardware_quantity: nil,
            hardware_description: nil,
            hardware_sales_price: nil,
            flat_rate_amount: nil,
            flat_rate_quantity: nil,
            invoiced_total: nil
        )
        switch type {
        case .hardware:
            payload.hardware_quantity = 1
        case .deployment_flat_rate:
            payload.flat_rate_quantity = 1
        case .time:
            break
        }
        return try await createTicket(payload)
    }
}

// MARK: - Create: Hardware & Client

extension APIClient {
    /// POST /api/v1/hardware
    /// Body accepts description, barcode, sales_price, acquisition_cost, common_vendors:[String]
    func createHardware(_ payload: [String: Any]) async throws -> Hardware {
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        let req = try makeRequest("/api/v1/hardware", method: "POST", body: body)
        return try await send(req)
    }
    
    /// POST /api/v1/clients
    /// Minimal server requirements: client_key, name. Arbitrary attributes allowed.
    func createClient(clientKey: String, name: String, attributes: [String: String]) async throws -> ClientRecord {
        var obj: [String: Any] = ["client_key": clientKey, "name": name]
        attributes.forEach { obj[$0.key] = $0.value }
        let body = try JSONSerialization.data(withJSONObject: obj, options: [])
        let req = try makeRequest("/api/v1/clients", method: "POST", body: body)
        
        // Server may return flat object or envelope; support both like updateClient
        let decoder = JSONDecoder()
        let (data, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Flat object { name:..., <attrs>... }
        if let flat = try? decoder.decode([String:String].self, from: data) {
            let nameOut = flat["name"] ?? name
            let attrs = flat.filter { $0.key != "name" }
            return ClientRecord(client_key: clientKey, name: nameOut, attributes: makeAttributes(from: attrs))
        }
        
        // Blob like ClientsEnvelope.ClientBlob
        if let blob = try? decoder.decode(ClientsEnvelope.ClientBlob.self, from: data) {
            let attrs = blob.extras.filter { $0.key != "name" }
            return ClientRecord(client_key: clientKey, name: blob.name, attributes: makeAttributes(from: attrs))
        }
        
        // Already flat ClientRecord?
        if let rec = try? decoder.decode(ClientRecord.self, from: data) {
            return rec
        }
        
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unrecognized client create response"))
    }
}

extension APIClient {
    /// POST /api/v1/clients
    /// Payload:
    /// {
    ///   "client_key": "<key>",
    ///   "client": { "name": "...", "display_name": "...", "support_rate": "...", "contract": Bool, ...custom }
    /// }
    func createClientV2(clientKey: String, clientObject: [String: Any]) async throws -> ClientRecord {
        let payload: [String: Any] = [
            "client_key": clientKey,
            "client": clientObject
        ]
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        let req = try makeRequest("/api/v1/clients", method: "POST", body: body)
        
        // Decode like updateClient: support multiple shapes
        let decoder = JSONDecoder()
        let (data, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // 1) Some servers echo back a flat object
        if let flat = try? decoder.decode([String:String].self, from: data) {
            let nameOut = flat["name"] ?? clientKey
            let attrs = flat.filter { $0.key != "name" }
            return ClientRecord(client_key: clientKey, name: nameOut, attributes: attrs.isEmpty ? nil : attrs)
        }
        
        // 2) Blob like ClientsEnvelope.ClientBlob
        if let blob = try? decoder.decode(ClientsEnvelope.ClientBlob.self, from: data) {
            let attrs = blob.extras.filter { $0.key != "name" }
            return ClientRecord(client_key: clientKey, name: blob.name, attributes: attrs.isEmpty ? nil : attrs)
        }
        
        // 3) Single-envelope { client_key, client: {...} }
        struct SingleEnvelope: Decodable {
            let client_key: String
            let client: [String:String]?
            let name: String?
        }
        if let env = try? decoder.decode(SingleEnvelope.self, from: data) {
            let nameOut = env.name ?? env.client?["name"] ?? env.client_key
            let attrs = env.client?.filter { $0.key != "name" } ?? [:]
            return ClientRecord(client_key: env.client_key, name: nameOut, attributes: makeAttributes(from: attrs))
        }
        
        // 4) Already a ClientRecord?
        if let rec = try? decoder.decode(ClientRecord.self, from: data) {
            return rec
        }
        
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unrecognized client create response"))
    }
}


// MARK: - Inventory

extension APIClient {
    struct InventoryReceiveRequest: Codable {
        let barcode: String
        let quantity: Int
        let acquisition_cost: String?
        let vendor: String?
        let note: String?
    }

    struct InventoryReceiveResponse: Decodable {
        struct TicketReference: Decodable {
            let id: Int?

            init(from decoder: Decoder) throws {
                if let single = try? decoder.singleValueContainer() {
                    if let intVal = try? single.decode(Int.self) {
                        self.id = intVal
                        return
                    }
                    if let stringVal = try? single.decode(String.self), let intVal = Int(stringVal) {
                        self.id = intVal
                        return
                    }
                }

                if let container = try? decoder.container(keyedBy: CodingKeys.self) {
                    self.id = try container.decodeIfPresent(Int.self, forKey: .id)
                } else {
                    self.id = nil
                }
            }

            private enum CodingKeys: String, CodingKey {
                case id
            }
        }

        struct Adjustment: Decodable {
            let id: Int?
            let barcode: String?
            let quantity: Int?
            let quantityChange: Int?
            let previousQuantity: Int?
            let newQuantity: Int?
            let note: String?
            let description: String?
            let message: String?
        }

        let ticket: TicketReference?
        let ticketId: Int?
        let adjustment: Adjustment?
        let message: String?
    }

    /// POST /api/v1/inventory/receive
    /// Sends a receive adjustment for a hardware item by barcode.
    /// Adjust the path if your API uses a different route.
    @discardableResult
    func receiveInventory(
        barcode: String,
        quantity: Int,
        acquisitionCost: String?,
        vendor: String?,
        note: String?
    ) async throws -> InventoryReceiveResponse {
        let payload = InventoryReceiveRequest(
            barcode: barcode,
            quantity: quantity,
            acquisition_cost: (acquisitionCost?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? acquisitionCost : nil,
            vendor: (vendor?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? vendor : nil,
            note: {
                let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
                return (trimmed?.isEmpty == false) ? trimmed : nil
            }()
        )
        let body = try JSONEncoder().encode(payload)
        let req = try makeRequest("/api/v1/inventory/receive", method: "POST", body: body)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try await send(req, decoder: decoder)
    }
}

