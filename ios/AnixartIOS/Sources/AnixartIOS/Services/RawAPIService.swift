import Foundation

struct RawAPIService: Sendable {
    let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    func get(_ path: String, query: [String: String] = [:], headers: [String: String] = [:]) async throws -> APIJSONResponse {
        try await client.request(path, query: query, headers: headers)
    }

    func postForm(_ path: String, form: [String: String], query: [String: String] = [:], headers: [String: String] = [:]) async throws -> APIJSONResponse {
        try await client.request(path, method: .post, query: query, form: form, headers: headers)
    }

    func postJSON<Body: Encodable>(_ path: String, body: Body, query: [String: String] = [:], headers: [String: String] = [:]) async throws -> APIJSONResponse {
        try await client.request(path, method: .post, query: query, body: body, headers: headers)
    }
}

struct APIJSONResponse: Decodable, APIStatus, Sendable {
    let code: Int
    let values: [String: JSONValue]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        var result: [String: JSONValue] = [:]
        for key in container.allKeys {
            result[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        values = result
        code = (try? container.decode(Int.self, forKey: DynamicKey("code"))) ?? 0
    }
}

enum JSONValue: Decodable, Sendable {
    case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else { self = .array(try container.decode([JSONValue].self)) }
    }
}

private struct DynamicKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init(_ stringValue: String) { self.stringValue = stringValue }
    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) { return nil }
}
