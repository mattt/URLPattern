import Foundation

/// A URL matcher based on the WHATWG URL Pattern API.
public struct URLPattern: Hashable, Sendable {
    public struct Options: Hashable, Sendable, Codable {
        public var ignoreCase: Bool

        public init(ignoreCase: Bool = false) {
            self.ignoreCase = ignoreCase
        }
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

    public var `protocol`: String { components.protocolPattern }
    public var username: String { components.usernamePattern }
    public var password: String { components.passwordPattern }
    public var hostname: String { components.hostnamePattern }
    public var port: String { components.portPattern }
    public var pathname: String { components.pathnamePattern }
    public var search: String { components.searchPattern }
    public var hash: String { components.hashPattern }
    public var hasRegExpGroups: Bool { components.hasRegExpGroups }
    public var options: Options { components.options }

    let components: PatternComponents

    public init(_ pattern: String, _ baseURL: String? = nil, options: Options = .init()) throws {
        self.components = try PatternComponents(
            patternString: pattern, baseURL: baseURL, options: options)
    }

    public init(_ pattern: Input, options: Options = .init()) throws {
        self.components = try PatternComponents(patternInput: pattern, options: options)
    }

    public func test(_ input: URL) -> Bool {
        (try? exec(input)) != nil
    }

    public func test(_ input: String, _ baseURL: String? = nil) -> Bool {
        (try? exec(input, baseURL)) != nil
    }

    public func test(_ input: Input) -> Bool {
        (try? exec(input)) != nil
    }

    public func exec(_ input: URL) throws -> Result? {
        try URLPatternMatcher.exec(components: components, input: .url(input))
    }

    public func exec(_ input: String, _ baseURL: String? = nil) throws -> Result? {
        try URLPatternMatcher.exec(components: components, input: .string(input, baseURL: baseURL))
    }

    public func exec(_ input: Input) throws -> Result? {
        try URLPatternMatcher.exec(components: components, input: .components(input))
    }
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
