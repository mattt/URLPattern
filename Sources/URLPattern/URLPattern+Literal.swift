import Foundation

extension URLPattern: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        do {
            try self.init(value)
        } catch {
            fatalError("Invalid URLPattern literal '\(value)': \(error)")
        }
    }
}
