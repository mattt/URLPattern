import Foundation

/// Canonical URL component values used for pattern compilation and matching.
struct URLPatternParts: Hashable, Sendable, Codable {
    var `protocol`: String
    var username: String
    var password: String
    var hostname: String
    var port: String
    var pathname: String
    var search: String
    var hash: String

    /// Returns the value stored for the given URL pattern component.
    subscript(component: URLPattern.Component) -> String {
        switch component {
        case .protocol: self.protocol
        case .username: username
        case .password: password
        case .hostname: hostname
        case .port: port
        case .pathname: pathname
        case .search: search
        case .hash: hash
        }
    }
}

// MARK: - Canonicalization

extension URLPatternParts {
    /// Creates canonical pattern components from user-supplied pattern input.
    init(forPattern input: URLPattern.Input) throws {
        let base = try input.baseURL.map(Self.parseBaseURL)
        let provided = Self.normalize(input)
        self = Self.inherit(provided: provided, from: base, wildcardForMissing: "*")
    }

    /// Creates canonical matching components from a concrete URL.
    init(matching url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw URLPatternError.invalidURLInput("Could not parse URL: \(url.absoluteString)")
        }

        let path: String
        if components.percentEncodedPath.isEmpty, components.host != nil {
            path = "/"
        } else if components.percentEncodedPath.isEmpty {
            path = ""
        } else {
            path =
                components.percentEncodedPath.removingPercentEncoding
                ?? components.percentEncodedPath
        }

        self.init(
            protocol: (components.scheme ?? "").lowercased(),
            username: components.percentEncodedUser.flatMap { $0.removingPercentEncoding }
                ?? (components.user ?? ""),
            password: components.percentEncodedPassword.flatMap { $0.removingPercentEncoding }
                ?? (components.password ?? ""),
            hostname: (components.host ?? "").lowercased(),
            port: components.port.map(String.init) ?? "",
            pathname: path,
            search: components.percentEncodedQuery.flatMap { $0.removingPercentEncoding }
                ?? (components.query ?? ""),
            hash: components.percentEncodedFragment.flatMap { $0.removingPercentEncoding }
                ?? (components.fragment ?? "")
        )
    }

    /// Creates canonical matching components from a URL string and optional base URL.
    init(matching string: String, baseURL: String?) throws {
        if let url = URL(string: string), url.scheme != nil {
            self = try .init(matching: url)
            return
        }

        if let baseURL,
            let base = URL(string: baseURL),
            let resolved = URL(string: string, relativeTo: base)?.absoluteURL
        {
            self = try .init(matching: resolved)
            return
        }

        let loose = URLPattern.Input(parsingLooseURL: string)
        try self.init(matching: loose)
    }

    /// Creates canonical matching components from structured URL input.
    init(matching input: URLPattern.Input) throws {
        let base = try input.baseURL.map(Self.parseBaseURL)
        let provided = Self.normalize(input)
        var parts = Self.inherit(provided: provided, from: base, wildcardForMissing: "")
        parts.protocol = parts.protocol.lowercased()
        parts.hostname = parts.hostname.lowercased()
        self = parts
    }
}

// MARK: - Private Helpers

extension URLPatternParts {
    /// Normalizes input fields to the canonical form used by matching and compilation.
    private static func normalize(_ input: URLPattern.Input) -> URLPattern.Input {
        URLPattern.Input(
            protocol: normalizeProtocol(input.protocol),
            username: input.username,
            password: input.password,
            hostname: input.hostname,
            port: input.port,
            pathname: normalizePathname(input.pathname),
            search: normalizeSearch(input.search),
            hash: normalizeHash(input.hash),
            baseURL: input.baseURL
        )
    }

    /// Inherits unspecified components from a base URL when allowed by component specificity.
    private static func inherit(
        provided: URLPattern.Input,
        from base: URLPatternParts?,
        wildcardForMissing: String
    ) -> URLPatternParts {
        guard let base else {
            return URLPatternParts(
                protocol: provided.protocol ?? wildcardForMissing,
                username: provided.username ?? wildcardForMissing,
                password: provided.password ?? wildcardForMissing,
                hostname: provided.hostname ?? wildcardForMissing,
                port: provided.port ?? wildcardForMissing,
                pathname: provided.pathname ?? wildcardForMissing,
                search: provided.search ?? wildcardForMissing,
                hash: provided.hash ?? wildcardForMissing
            )
        }

        let specificity: [URLPattern.Component] = [
            .protocol, .hostname, .port, .pathname, .search, .hash,
        ]
        let providedMap: [URLPattern.Component: String?] = [
            .protocol: provided.protocol,
            .hostname: provided.hostname,
            .port: provided.port,
            .pathname: provided.pathname,
            .search: provided.search,
            .hash: provided.hash,
        ]
        let baseMap: [URLPattern.Component: String] = [
            .protocol: base.protocol,
            .hostname: base.hostname,
            .port: base.port,
            .pathname: base.pathname,
            .search: base.search,
            .hash: base.hash,
        ]

        let lastSpecified = specificity.lastIndex { component in
            if case .some(.some) = providedMap[component] {
                return true
            }
            return false
        }

        var inheritedMain: [URLPattern.Component: String] = [:]
        for (index, component) in specificity.enumerated() {
            switch providedMap[component] {
            case .some(let value?):
                inheritedMain[component] = value
                continue
            default:
                break
            }

            let canInherit: Bool
            if let lastSpecified {
                canInherit = index <= lastSpecified
            } else {
                canInherit = true
            }

            if canInherit {
                inheritedMain[component] = baseMap[component] ?? wildcardForMissing
            } else {
                inheritedMain[component] = wildcardForMissing
            }
        }

        // WHATWG: credentials do not inherit from base URL.
        let username = provided.username ?? wildcardForMissing
        let password = provided.password ?? wildcardForMissing

        return URLPatternParts(
            protocol: inheritedMain[.protocol] ?? wildcardForMissing,
            username: username,
            password: password,
            hostname: inheritedMain[.hostname] ?? wildcardForMissing,
            port: inheritedMain[.port] ?? wildcardForMissing,
            pathname: inheritedMain[.pathname] ?? wildcardForMissing,
            search: inheritedMain[.search] ?? wildcardForMissing,
            hash: inheritedMain[.hash] ?? wildcardForMissing
        )
    }

    /// Parses and canonicalizes a base URL string into component parts.
    fileprivate static func parseBaseURL(_ value: String) throws -> URLPatternParts {
        guard let url = URL(string: value) else {
            throw URLPatternError.invalidBaseURL(value)
        }
        return try .init(matching: url)
    }

    /// Normalizes a protocol value by removing a trailing colon.
    private static func normalizeProtocol(_ value: String?) -> String? {
        guard var value else { return nil }
        if value.hasSuffix(":") {
            value.removeLast()
        }
        return value
    }

    /// Normalizes a pathname value and maps an empty path to `/`.
    private static func normalizePathname(_ value: String?) -> String? {
        guard let value else { return nil }
        if value.isEmpty {
            return "/"
        }
        return value
    }

    /// Normalizes a search value by removing a leading question mark.
    private static func normalizeSearch(_ value: String?) -> String? {
        guard var value else { return nil }
        if value.hasPrefix("?") {
            value.removeFirst()
        }
        return value
    }

    /// Normalizes a hash value by removing a leading number sign.
    private static func normalizeHash(_ value: String?) -> String? {
        guard var value else { return nil }
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        return value
    }
}
