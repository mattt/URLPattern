import Foundation

struct URLPatternParts: Hashable, Sendable, Codable {
    var `protocol`: String
    var username: String
    var password: String
    var hostname: String
    var port: String
    var pathname: String
    var search: String
    var hash: String
}

enum URLPatternCanonicalizer {
    static func canonicalPatternInput(_ input: URLPattern.Input) throws -> URLPatternParts {
        let base = try input.baseURL.map(parseBaseURL(_:))

        let provided = normalizeInput(input)
        return inherit(
            provided: provided,
            from: base,
            wildcardForMissing: "*"
        )
    }

    static func canonicalMatchInput(_ input: URLPattern.Input) throws -> URLPatternParts {
        let base = try input.baseURL.map(parseBaseURL(_:))
        let provided = normalizeInput(input)
        let inherited = inherit(
            provided: provided,
            from: base,
            wildcardForMissing: ""
        )

        return URLPatternParts(
            protocol: inherited.protocol.lowercased(),
            username: inherited.username,
            password: inherited.password,
            hostname: inherited.hostname.lowercased(),
            port: inherited.port,
            pathname: inherited.pathname,
            search: inherited.search,
            hash: inherited.hash
        )
    }

    static func canonicalMatchURL(_ url: URL) throws -> URLPatternParts {
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

        return URLPatternParts(
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

    static func canonicalMatchString(_ input: String, baseURL: String?) throws -> URLPatternParts {
        if let url = URL(string: input), url.scheme != nil {
            return try canonicalMatchURL(url)
        }

        if let baseURL,
            let base = URL(string: baseURL),
            let resolved = URL(string: input, relativeTo: base)?.absoluteURL
        {
            return try canonicalMatchURL(resolved)
        }

        // Fallback to loose parsing for pathname-only matching.
        let loose = URLPatternStringParser.parseLooseURLString(input)
        return try canonicalMatchInput(loose)
    }

    private static func normalizeInput(_ input: URLPattern.Input) -> URLPattern.Input {
        URLPattern.Input(
            protocol: normalizeProtocol(input.protocol),
            username: input.username,
            password: input.password,
            hostname: normalizeHostname(input.hostname),
            port: normalizePort(input.port),
            pathname: normalizePathname(input.pathname),
            search: normalizeSearch(input.search),
            hash: normalizeHash(input.hash),
            baseURL: input.baseURL
        )
    }

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

        let specificity: [URLPatternComponent] = [
            .protocol, .hostname, .port, .pathname, .search, .hash,
        ]
        let providedMap: [URLPatternComponent: String?] = [
            .protocol: provided.protocol,
            .hostname: provided.hostname,
            .port: provided.port,
            .pathname: provided.pathname,
            .search: provided.search,
            .hash: provided.hash,
        ]
        let baseMap: [URLPatternComponent: String] = [
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

        var inheritedMain: [URLPatternComponent: String] = [:]
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

        // WHATWG behavior: credentials do not inherit from base URL.
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

    private static func parseBaseURL(_ value: String) throws -> URLPatternParts {
        guard let url = URL(string: value) else {
            throw URLPatternError.invalidBaseURL(value)
        }

        return try canonicalMatchURL(url)
    }

    private static func normalizeProtocol(_ value: String?) -> String? {
        guard var value else { return nil }
        if value.hasSuffix(":") {
            value.removeLast()
        }
        return value
    }

    private static func normalizeHostname(_ value: String?) -> String? {
        value
    }

    private static func normalizePort(_ value: String?) -> String? {
        value
    }

    private static func normalizePathname(_ value: String?) -> String? {
        guard let value else { return nil }
        if value.isEmpty {
            return "/"
        }
        return value
    }

    private static func normalizeSearch(_ value: String?) -> String? {
        guard var value else { return nil }
        if value.hasPrefix("?") {
            value.removeFirst()
        }
        return value
    }

    private static func normalizeHash(_ value: String?) -> String? {
        guard var value else { return nil }
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        return value
    }
}
