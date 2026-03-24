import Foundation

public enum URLPatternError: Error, LocalizedError, Sendable {
    case invalidPattern(String)
    case invalidBaseURL(String)
    case invalidURLInput(String)
    case invalidComponent(String)
    case unsupported(String)
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
