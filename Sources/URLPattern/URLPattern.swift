import Foundation

/// A URL matcher based on the WHATWG URL Pattern API.
public struct URLPattern: Hashable, Sendable {
    public struct Options: Hashable, Sendable, Codable {
        public var ignoreCase: Bool

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
        public var `protocol`: String?
        public var username: String?
        public var password: String?
        public var hostname: String?
        public var port: String?
        public var pathname: String?
        public var search: String?
        public var hash: String?
        public var baseURL: String?

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

    public struct ComponentResult: Hashable, Sendable, Codable {
        public var input: String
        public var groups: [String: String]

        public init(input: String, groups: [String: String]) {
            self.input = input
            self.groups = groups
        }
    }

    public struct Result: Hashable, Sendable, Codable {
        public var inputs: [String]
        public var `protocol`: ComponentResult
        public var username: ComponentResult
        public var password: ComponentResult
        public var hostname: ComponentResult
        public var port: ComponentResult
        public var pathname: ComponentResult
        public var search: ComponentResult
        public var hash: ComponentResult

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

    public var `protocol`: String { patterns.protocol }
    public var username: String { patterns.username }
    public var password: String { patterns.password }
    public var hostname: String { patterns.hostname }
    public var port: String { patterns.port }
    public var pathname: String { patterns.pathname }
    public var search: String { patterns.search }
    public var hash: String { patterns.hash }
    public let hasRegexGroups: Bool
    public let options: Options

    let patterns: URLPatternParts
    let compiled: [Component: CompiledComponentPattern]

    public init(_ pattern: String, _ baseURL: String? = nil, options: Options = .init()) throws {
        try self.init(.init(parsing: pattern, baseURL: baseURL), options: options)
    }

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

    public func test(_ input: URL) -> Bool {
        (try? exec(input)) != nil
    }

    public func test(_ input: String, _ baseURL: String? = nil) -> Bool {
        (try? exec(input, baseURL)) != nil
    }

    public func test(_ input: Input) -> Bool {
        (try? exec(input)) != nil
    }

    // MARK: - Execution

    public func exec(_ input: URL) throws -> Result? {
        let canonical = try URLPatternParts(matching: input)
        return matchAll(against: canonical, rawInput: input.absoluteString)
    }

    public func exec(_ input: String, _ baseURL: String? = nil) throws -> Result? {
        let canonical = try URLPatternParts(matching: input, baseURL: baseURL)
        return matchAll(against: canonical, rawInput: input)
    }

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
    init(parsing patternString: String, baseURL: String?) {
        if patternString.contains("://") {
            self = .init(parsingLooseURL: patternString)
        } else {
            self = .init(pathname: patternString)
        }
        self.baseURL = baseURL
    }

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

public func ~= (lhs: URLPattern, rhs: URL) -> Bool {
    lhs.test(rhs)
}

public func ~= (lhs: URLPattern, rhs: String) -> Bool {
    lhs.test(rhs)
}
