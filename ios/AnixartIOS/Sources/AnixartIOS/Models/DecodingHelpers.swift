import Foundation

extension KeyedDecodingContainer {
    /// Безопасно декодирует вложенный объект. Если сервер прислал целочисленный
    /// идентификатор (Jackson `@JsonIdentityInfo` / `@id` back-reference), возвращает `nil` вместо `typeMismatch`.
    func decodeObjectOrIgnoreRefIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        guard contains(key) else { return nil }
        if try decodeNil(forKey: key) { return nil }
        if (try? decode(Int64.self, forKey: key)) != nil {
            return nil
        }
        return try decode(T.self, forKey: key)
    }
}
