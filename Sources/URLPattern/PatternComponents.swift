import Foundation

struct PatternComponents: Hashable, Sendable {
    var protocolPattern: String
    var usernamePattern: String
    var passwordPattern: String
    var hostnamePattern: String
    var portPattern: String
    var pathnamePattern: String
    var searchPattern: String
    var hashPattern: String
    var options: URLPattern.Options
    var hasRegExpGroups: Bool

    private var compiledByComponent: [URLPatternComponent: CompiledComponentPattern]

    init(patternString: String, baseURL: String?, options: URLPattern.Options) throws {
        let parsed = URLPatternStringParser.parsePatternString(patternString, baseURL: baseURL)
        try self.init(patternInput: parsed, options: options)
    }

    init(patternInput: URLPattern.Input, options: URLPattern.Options) throws {
        let parts = try URLPatternCanonicalizer.canonicalPatternInput(patternInput)
        self.protocolPattern = parts.protocol
        self.usernamePattern = parts.username
        self.passwordPattern = parts.password
        self.hostnamePattern = parts.hostname
        self.portPattern = parts.port
        self.pathnamePattern = parts.pathname
        self.searchPattern = parts.search
        self.hashPattern = parts.hash
        self.options = options

        let compileOptions = URLPatternCompiler.CompileOptions(ignoreCase: options.ignoreCase)
        let protocolCompiled = try URLPatternCompiler.compile(
            component: .protocol, pattern: parts.protocol, options: compileOptions)
        let usernameCompiled = try URLPatternCompiler.compile(
            component: .username, pattern: parts.username, options: compileOptions)
        let passwordCompiled = try URLPatternCompiler.compile(
            component: .password, pattern: parts.password, options: compileOptions)
        let hostnameCompiled = try URLPatternCompiler.compile(
            component: .hostname, pattern: parts.hostname, options: compileOptions)
        let portCompiled = try URLPatternCompiler.compile(
            component: .port, pattern: parts.port, options: compileOptions)
        let pathnameCompiled = try URLPatternCompiler.compile(
            component: .pathname, pattern: parts.pathname, options: compileOptions)
        let searchCompiled = try URLPatternCompiler.compile(
            component: .search, pattern: parts.search, options: compileOptions)
        let hashCompiled = try URLPatternCompiler.compile(
            component: .hash, pattern: parts.hash, options: compileOptions)

        self.compiledByComponent = [
            .protocol: protocolCompiled,
            .username: usernameCompiled,
            .password: passwordCompiled,
            .hostname: hostnameCompiled,
            .port: portCompiled,
            .pathname: pathnameCompiled,
            .search: searchCompiled,
            .hash: hashCompiled,
        ]
        self.hasRegExpGroups = [
            protocolCompiled.hasRegExpGroups,
            usernameCompiled.hasRegExpGroups,
            passwordCompiled.hasRegExpGroups,
            hostnameCompiled.hasRegExpGroups,
            portCompiled.hasRegExpGroups,
            pathnameCompiled.hasRegExpGroups,
            searchCompiled.hasRegExpGroups,
            hashCompiled.hasRegExpGroups,
        ].contains(true)
    }

    func compiled(_ component: URLPatternComponent) -> CompiledComponentPattern {
        compiledByComponent[component]!
    }

    static func == (lhs: PatternComponents, rhs: PatternComponents) -> Bool {
        lhs.protocolPattern == rhs.protocolPattern && lhs.usernamePattern == rhs.usernamePattern
            && lhs.passwordPattern == rhs.passwordPattern
            && lhs.hostnamePattern == rhs.hostnamePattern && lhs.portPattern == rhs.portPattern
            && lhs.pathnamePattern == rhs.pathnamePattern && lhs.searchPattern == rhs.searchPattern
            && lhs.hashPattern == rhs.hashPattern && lhs.options == rhs.options
            && lhs.hasRegExpGroups == rhs.hasRegExpGroups
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(protocolPattern)
        hasher.combine(usernamePattern)
        hasher.combine(passwordPattern)
        hasher.combine(hostnamePattern)
        hasher.combine(portPattern)
        hasher.combine(pathnamePattern)
        hasher.combine(searchPattern)
        hasher.combine(hashPattern)
        hasher.combine(options)
        hasher.combine(hasRegExpGroups)
    }
}
