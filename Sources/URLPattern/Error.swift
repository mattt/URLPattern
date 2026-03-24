import Foundation

/// Errors thrown while parsing, compiling, or matching URL patterns.
public enum URLPatternError: Error, LocalizedError, Sendable {
    /// The pattern string contains invalid URL pattern syntax.
    case invalidPattern(String)
    /// The base URL cannot be parsed into a valid URL.
    case invalidBaseURL(String)
    /// The runtime URL input cannot be parsed into components.
    case invalidURLInput(String)
    /// A URL component value is invalid for matching.
    case invalidComponent(String)
    /// The operation requires a URL pattern feature that is not supported.
    case unsupported(String)
    /// The generated regular expression cannot be compiled.
    case regexCompilationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPattern(let message):
            return "Invalid URLPattern: \(message)"
        case .invalidBaseURL(let message):
            return "Invalid base URL: \(message)"
        case .invalidURLInput(let message):
            return "Invalid URL input: \(message)"
        case .invalidComponent(let message):
            return "Invalid URL component: \(message)"
        case .unsupported(let message):
            return "Unsupported URLPattern feature: \(message)"
        case .regexCompilationFailed(let message):
            return "Failed to compile pattern regex: \(message)"
        }
    }
}
