//
//  APIClient.swift
//  Thin URLSession wrapper. Unused by the mock services today;
//  the real MetadataService / auth backend plug in here later.
//

import Foundation

enum HTTPMethod: String { case get = "GET", post = "POST", put = "PUT", delete = "DELETE" }

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case requestFailed(status: Int)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: String(localized: "error.invalidURL", defaultValue: "That link doesn't look valid.")
        case .requestFailed: String(localized: "error.request", defaultValue: "The server couldn't complete the request.")
        case .decoding: String(localized: "error.decoding", defaultValue: "Unexpected response from the server.")
        case .transport: String(localized: "error.network", defaultValue: "Network error. Check your connection and try again.")
        }
    }
}

struct APIEndpoint {
    var path: String
    var method: HTTPMethod = .get
    var query: [URLQueryItem] = []
    var body: Data?
}

protocol APIClient: Sendable {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
}

struct URLSessionAPIClient: APIClient {
    var baseURL: URL
    var session: URLSession = .shared

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        guard var components = URLComponents(url: baseURL.appending(path: endpoint.path),
                                             resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }
        if !endpoint.query.isEmpty { components.queryItems = endpoint.query }
        guard let url = components.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        if endpoint.body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw NetworkError.requestFailed(status: http.statusCode)
            }
            do { return try JSONDecoder().decode(T.self, from: data) }
            catch { throw NetworkError.decoding(error) }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.transport(error)
        }
    }
}
