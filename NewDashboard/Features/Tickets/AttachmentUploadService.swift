import Foundation

actor AttachmentUploadService {
    struct UploadRequest: Codable {
        let fileName: String
        let contentType: String
        let size: Int
    }

    struct UploadResponse: Codable {
        let uploadURL: URL
        let attachment: AttachmentDTO
    }

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func upload(data: Data, fileName: String, contentType: String) async throws -> AttachmentDTO {
        let request = UploadRequest(fileName: fileName, contentType: contentType, size: data.count)
        let endpoint = Endpoint<UploadResponse>(path: "/api/v1/attachments",
                                                method: .post,
                                                body: try Endpoint.jsonBody(request))
        let response = try await apiClient.send(endpoint)
        guard let payload = response.value else { throw APIError.server(status: response.statusCode) }

        var urlRequest = URLRequest(url: payload.uploadURL)
        urlRequest.httpMethod = HTTPMethod.put.rawValue
        urlRequest.httpBody = data
        urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let (_, uploadResponse) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = uploadResponse as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw APIError.server(status: (uploadResponse as? HTTPURLResponse)?.statusCode ?? 500)
        }
        return payload.attachment
    }
}
