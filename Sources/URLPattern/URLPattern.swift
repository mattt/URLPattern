import Foundation

/// A URL matcher based on the WHATWG URL Pattern API.
public struct URLPattern: Hashable, Sendable {
    /// Options that control URL pattern compilation and matching behavior.
    public struct Options: Hashable, Sendable, Codable {
        /// A Boolean value that indicates whether matching ignores letter case.
        public var ignoreCase: Bool

        /// Creates options for URL pattern matching.
        ///
        /// - Parameter ignoreCase: A Boolean value that indicates whether matching ignores letter case.
        public init(ignoreCase: Bool = false) {
            self.ignoreCase = ignoreCase
        }
    }

    enum Component: String, CaseIterable, Sendable, Codable {
        case `protocol`
        case username
        case password
        case hostname
        case port
        case pathname
        case search
        case hash
    }

    /// Structured initializer and match input.
    public struct Input: Hashable, Sendable, Codable {
        /// The URL scheme component pattern, without a trailing colon.
        public var `protocol`: String?
        /// The username component pattern.
        public var username: String?
        /// The password component pattern.
        public var password: String?
        /// The hostname component pattern.
        public var hostname: String?
        /// The port component pattern.
        public var port: String?
        /// The pathname component pattern.
        public var pathname: String?
        /// The search component pattern, without a leading question mark.
        public var search: String?
        /// The hash component pattern, without a leading number sign.
        public var hash: String?
        /// The optional base URL used to resolve and inherit missing components.
        public var baseURL: String?

        /// Creates a structured pattern input value.
        ///
        /// - Parameters:
        ///   - protocol: The URL scheme component pattern, without a trailing colon.
        ///   - username: The username component pattern.
        ///   - password: The password component pattern.
        ///   - hostname: The hostname component pattern.
        ///   - port: The port component pattern.
        ///   - pathname: The pathname component pattern.
        ///   - search: The search component pattern, without a leading question mark.
        ///   - hash: The hash component pattern, without a leading number sign.
        ///   - baseURL: The optional base URL used to resolve and inherit missing components.
        public init(
            protocol: String? = nil,
            username: String? = nil,
            password: String? = nil,
            hostname: String? = nil,
            port: String? = nil,
            pathname: String? = nil,
            search: String? = nil,
            hash: String? = nil,
            baseURL: String? = nil
        ) {
            self.protocol = `protocol`
            self.username = username
            self.password = password
            self.hostname = hostname
            self.port = port
            self.pathname = pathname
            self.search = search
            self.hash = hash
            self.baseURL = baseURL
        }
    }

    /// The match result for one URL component.
    public struct ComponentResult: Hashable, Sendable, Codable {
        /// The full input value that matched this component.
        public var input: String
        /// Captured group values keyed by group name or by numeric string index.
        public var groups: [String: String]

        /// Creates a component match result.
        ///
        /// - Parameters:
        ///   - input: The full input value that matched this component.
        ///   - groups: Captured group values keyed by group name or by numeric string index.
        public init(input: String, groups: [String: String]) {
            self.input = input
            self.groups = groups
        }
    }

    /// The complete match result across all URL components.
    public struct Result: Hashable, Sendable, Codable {
        /// The original raw input strings used to attempt the match.
        public var inputs: [String]
        /// The match result for the protocol component.
        public var `protocol`: ComponentResult
        /// The match result for the username component.
        public var username: ComponentResult
        /// The match result for the password component.
        public var password: ComponentResult
        /// The match result for the hostname component.
        public var hostname: ComponentResult
        /// The match result for the port component.
        public var port: ComponentResult
        /// The match result for the pathname component.
        public var pathname: ComponentResult
        /// The match result for the search component.
        public var search: ComponentResult
        /// The match result for the hash component.
        public var hash: ComponentResult

        /// Creates a complete URL pattern match result.
        ///
        /// - Parameters:
        ///   - inputs: The original raw input strings used to attempt the match.
        ///   - protocol: The match result for the protocol component.
        ///   - username: The match result for the username component.
        ///   - password: The match result for the password component.
        ///   - hostname: The match result for the hostname component.
        ///   - port: The match result for the port component.
        ///   - pathname: The match result for the pathname component.
        ///   - search: The match result for the search component.
        ///   - hash: The match result for the hash component.
        public init(
            inputs: [String],
            protocol: ComponentResult,
            username: ComponentResult,
            password: ComponentResult,
            hostname: ComponentResult,
            port: ComponentResult,
            pathname: ComponentResult,
            search: ComponentResult,
            hash: ComponentResult
        ) {
            self.inputs = inputs
            self.protocol = `protocol`
            self.username = username
            self.password = password
            self.hostname = hostname
            self.port = port
            self.pathname = pathname
            self.search = search
            self.hash = hash
        }
    }

    /// The protocol pattern string.
    public var `protocol`: String { patterns.protocol }
    /// The username pattern string.
    public var username: String { patterns.username }
    /// The password pattern string.
    public var password: String { patterns.password }
    /// The hostname pattern string.
    public var hostname: String { patterns.hostname }
    /// The port pattern string.
    public var port: String { patterns.port }
    /// The pathname pattern string.
    public var pathname: String { patterns.pathname }
    /// The search pattern string.
    public var search: String { patterns.search }
    /// The hash pattern string.
    public var hash: String { patterns.hash }
    /// A Boolean value that indicates whether any component includes regex groups.
    public let hasRegexGroups: Bool
    /// The options used to compile this pattern.
    public let options: Options

    let patterns: URLPatternParts
    let compiled: [Component: CompiledComponentPattern]

    /// Creates a pattern from a pattern string and optional base URL.
    ///
    /// - Parameters:
    ///   - pattern: The URL pattern string to parse and compile.
    ///   - baseURL: An optional base URL used to resolve relative input components.
    ///   - options: Options that control matching behavior.
    /// - Throws: `URLPatternError` when parsing or compilation fails.
    public init(_ pattern: String, _ baseURL: String? = nil, options: Options = .init()) throws {
        try self.init(.init(parsing: pattern, baseURL: baseURL), options: options)
    }

    /// Creates a pattern from structured component input.
    ///
    /// - Parameters:
    ///   - input: Structured URL component patterns.
    ///   - options: Options that control matching behavior.
    /// - Throws: `URLPatternError` when normalization or compilation fails.
    public init(_ input: Input, options: Options = .init()) throws {
        let parts = try URLPatternParts(forPattern: input)
        self.patterns = parts
        self.options = options

        var compiled: [Component: CompiledComponentPattern] = [:]
        var hasRegexGroups = false
        for component in Component.allCases {
            let result = try CompiledComponentPattern(
                compiling: parts[component], for: component, ignoreCase: options.ignoreCase)
            compiled[component] = result
            hasRegexGroups = hasRegexGroups || result.hasRegexGroups
        }
        self.compiled = compiled
        self.hasRegexGroups = hasRegexGroups
    }

    // MARK: - Testing

    /// Returns whether this pattern matches the given URL.
    ///
    /// - Parameter input: The URL to test.
    /// - Returns: `true` when the URL matches this pattern; otherwise, `false`.
    public func test(_ input: URL) -> Bool {
        (try? exec(input)) != nil
    }

    /// Returns whether this pattern matches the given URL string.
    ///
    /// - Parameters:
    ///   - input: The URL string to test.
    ///   - baseURL: An optional base URL used to resolve relative URL strings.
    /// - Returns: `true` when the URL string matches this pattern; otherwise, `false`.
    public func test(_ input: String, _ baseURL: String? = nil) -> Bool {
        (try? exec(input, baseURL)) != nil
    }

    /// Returns whether this pattern matches the given structured input.
    ///
    /// - Parameter input: Structured URL components to test.
    /// - Returns: `true` when the input matches this pattern; otherwise, `false`.
    public func test(_ input: Input) -> Bool {
        (try? exec(input)) != nil
    }

    // MARK: - Execution

    /// Executes this pattern against the given URL.
    ///
    /// - Parameter input: The URL to match.
    /// - Returns: A match result when the URL matches; otherwise, `nil`.
    /// - Throws: `URLPatternError` when input canonicalization fails.
    public func exec(_ input: URL) throws -> Result? {
        let canonical = try URLPatternParts(matching: input)
        return matchAll(against: canonical, rawInput: input.absoluteString)
    }

    /// Executes this pattern against the given URL string.
    ///
    /// - Parameters:
    ///   - input: The URL string to match.
    ///   - baseURL: An optional base URL used to resolve relative URL strings.
    /// - Returns: A match result when the URL string matches; otherwise, `nil`.
    /// - Throws: `URLPatternError` when URL parsing or canonicalization fails.
    public func exec(_ input: String, _ baseURL: String? = nil) throws -> Result? {
        let canonical = try URLPatternParts(matching: input, baseURL: baseURL)
        return matchAll(against: canonical, rawInput: input)
    }

    /// Executes this pattern against structured URL components.
    ///
    /// - Parameter input: Structured URL components to match.
    /// - Returns: A match result when the input matches; otherwise, `nil`.
    /// - Throws: `URLPatternError` when canonicalization fails.
    public func exec(_ input: Input) throws -> Result? {
        let canonical = try URLPatternParts(matching: input)
        let rawInput = [
            input.protocol, input.username, input.password,
            input.hostname, input.port, input.pathname,
            input.search, input.hash,
        ]
        .compactMap { $0 }
        .joined(separator: "|")
        return matchAll(against: canonical, rawInput: rawInput)
    }
}

// MARK: - Matching

extension URLPattern {
    private func matchAll(
        against canonical: URLPatternParts,
        rawInput: String
    ) -> Result? {
        var results: [Component: ComponentResult] = [:]
        for component in Component.allCases {
            guard let result = Self.match(compiled[component]!, against: canonical[component])
            else {
                return nil
            }
            results[component] = result
        }

        return Result(
            inputs: [rawInput],
            protocol: results[.protocol]!,
            username: results[.username]!,
            password: results[.password]!,
            hostname: results[.hostname]!,
            port: results[.port]!,
            pathname: results[.pathname]!,
            search: results[.search]!,
            hash: results[.hash]!
        )
    }

    private static func match(
        _ compiled: CompiledComponentPattern,
        against value: String
    ) -> ComponentResult? {
        let nsString = value as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let result = compiled.regex.firstMatch(in: value, options: [], range: range) else {
            return nil
        }
        guard NSEqualRanges(result.range, range) else {
            return nil
        }

        var groups: [String: String] = [:]
        var unnamedIndex = 0
        for (offset, capture) in compiled.captures.enumerated() {
            let captureRangeIndex = offset + 1
            guard captureRangeIndex < result.numberOfRanges else {
                continue
            }

            let captureRange = result.range(at: captureRangeIndex)
            guard captureRange.location != NSNotFound else {
                continue
            }
            let captureValue = nsString.substring(with: captureRange)

            switch capture.kind {
            case .named(let name):
                groups[name] = captureValue
            case .unnamed:
                groups[String(unnamedIndex)] = captureValue
                unnamedIndex += 1
            }
        }

        return ComponentResult(input: value, groups: groups)
    }
}

// MARK: - Input Parsing

extension URLPattern.Input {
    /// Parses a pattern string into structured URL pattern input.
    init(parsing patternString: String, baseURL: String?) {
        if patternString.contains("://") {
            self = .init(parsingLooseURL: patternString)
        } else {
            self = .init(pathname: patternString)
        }
        self.baseURL = baseURL
    }

    /// Parses a URL-like value into structured components without strict URL validation.
    init(parsingLooseURL value: String) {
        var working = value

        var hash: String?
        if let hashRange = firstUnescapedCharacter("#", in: working) {
            hash = String(working[working.index(after: hashRange)...])
            working = String(working[..<hashRange])
        }

        var search: String?
        if let searchRange = firstUnescapedCharacter("?", in: working) {
            search = String(working[working.index(after: searchRange)...])
            working = String(working[..<searchRange])
        }

        if let schemeRange = working.range(of: "://") {
            let scheme = String(working[..<schemeRange.lowerBound])
            let remainder = String(working[schemeRange.upperBound...])
            let authorityEnd = remainder.firstIndex(where: { $0 == "/" })
            let authority: String
            let path: String
            if let authorityEnd {
                authority = String(remainder[..<authorityEnd])
                path = String(remainder[authorityEnd...])
            } else {
                authority = remainder
                path = ""
            }

            let authorityParts = parseAuthority(authority)

            self = .init(
                protocol: scheme,
                username: authorityParts.username,
                password: authorityParts.password,
                hostname: authorityParts.hostname,
                port: authorityParts.port,
                pathname: path.isEmpty ? "/" : path,
                search: search,
                hash: hash
            )
            return
        }

        self = .init(
            pathname: working.isEmpty ? "/" : working,
            search: search,
            hash: hash
        )
    }
}

/// Parses authority text into userinfo, host, and port components.
private func parseAuthority(_ authority: String) -> (
    username: String?, password: String?, hostname: String?, port: String?
) {
    var working = authority
    var username: String?
    var password: String?

    if let atIndex = working.lastIndex(of: "@") {
        let userInfo = String(working[..<atIndex])
        working = String(working[working.index(after: atIndex)...])
        if let separator = userInfo.firstIndex(of: ":") {
            username = String(userInfo[..<separator])
            password = String(userInfo[userInfo.index(after: separator)...])
        } else {
            username = userInfo
        }
    }

    if working.hasPrefix("[") {
        if let end = working.firstIndex(of: "]") {
            let host = String(working[...end])
            let restStart = working.index(after: end)
            let rest = restStart < working.endIndex ? String(working[restStart...]) : ""
            let port = rest.hasPrefix(":") ? String(rest.dropFirst()) : nil
            return (username, password, host, port)
        }
        return (username, password, working, nil)
    }

    if let separator = working.lastIndex(of: ":") {
        let host = String(working[..<separator])
        let possiblePort = String(working[working.index(after: separator)...])
        if possiblePort.isEmpty == false {
            return (username, password, host, possiblePort)
        }
    }

    return (username, password, working.isEmpty ? nil : working, nil)
}

/// Returns the first unescaped occurrence of a character in a string.
private func firstUnescapedCharacter(_ character: Character, in string: String) -> String.Index? {
    var index = string.startIndex
    while index < string.endIndex {
        let current = string[index]
        if current == "\\" {
            index = string.index(after: index)
            if index < string.endIndex {
                index = string.index(after: index)
            }
            continue
        }

        if current == character {
            return index
        }

        index = string.index(after: index)
    }

    return nil
}

// MARK: - Codable

extension URLPattern: Codable {
    enum CodingKeys: String, CodingKey {
        case `protocol`
        case username
        case password
        case hostname
        case port
        case pathname
        case search
        case hash
        case baseURL
        case ignoreCase
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
            let pattern = try? container.decode(String.self)
        {
            try self.init(pattern)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let input = Input(
            protocol: try container.decodeIfPresent(String.self, forKey: .protocol),
            username: try container.decodeIfPresent(String.self, forKey: .username),
            password: try container.decodeIfPresent(String.self, forKey: .password),
            hostname: try container.decodeIfPresent(String.self, forKey: .hostname),
            port: try container.decodeIfPresent(String.self, forKey: .port),
            pathname: try container.decodeIfPresent(String.self, forKey: .pathname),
            search: try container.decodeIfPresent(String.self, forKey: .search),
            hash: try container.decodeIfPresent(String.self, forKey: .hash),
            baseURL: try container.decodeIfPresent(String.self, forKey: .baseURL)
        )

        let options = Options(
            ignoreCase: try container.decodeIfPresent(Bool.self, forKey: .ignoreCase) ?? false
        )
        try self.init(input, options: options)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.protocol, forKey: .protocol)
        try container.encode(username, forKey: .username)
        try container.encode(password, forKey: .password)
        try container.encode(hostname, forKey: .hostname)
        try container.encode(port, forKey: .port)
        try container.encode(pathname, forKey: .pathname)
        try container.encode(search, forKey: .search)
        try container.encode(hash, forKey: .hash)
        try container.encode(options.ignoreCase, forKey: .ignoreCase)
    }
}

// MARK: - ExpressibleByStringLiteral

extension URLPattern: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        do {
            try self.init(value)
        } catch {
            fatalError("Invalid URLPattern literal '\(value)': \(error)")
        }
    }
}

// MARK: - Pattern Matching

/// Returns whether a URL matches a URL pattern.
public func ~= (lhs: URLPattern, rhs: URL) -> Bool {
    lhs.test(rhs)
}

/// Returns whether a URL string matches a URL pattern.
public func ~= (lhs: URLPattern, rhs: String) -> Bool {
    lhs.test(rhs)
}
