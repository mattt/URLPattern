import Foundation

/// A compiled regular-expression representation of one URL pattern component.
struct CompiledComponentPattern: Sendable {
    var regexPattern: String
    var regexOptions: NSRegularExpression.Options
    var captures: [CaptureInfo]
    var hasRegexGroups: Bool

    /// Returns the compiled regular expression for this component pattern.
    var regex: NSRegularExpression {
        try! NSRegularExpression(pattern: regexPattern, options: regexOptions)
    }

    /// Compiles a component pattern string into a regular-expression matcher.
    init(compiling pattern: String, for component: URLPattern.Component, ignoreCase: Bool) throws {
        if pattern == "*" {
            self.regexPattern = "^([\\s\\S]*)$"
            self.regexOptions = Self.regexOptions(for: component, ignoreCase: ignoreCase)
            self.captures = [.init(kind: .unnamed)]
            self.hasRegexGroups = false
            return
        }

        var parser = Parser(source: pattern, component: component)
        let body = try parser.parse(until: nil, disablePathnamePrefixing: false)
        let regexPattern = "^\(body)$"
        let options = Self.regexOptions(for: component, ignoreCase: ignoreCase)

        do {
            _ = try NSRegularExpression(pattern: regexPattern, options: options)
        } catch {
            throw URLPatternError.regexCompilationFailed(error.localizedDescription)
        }

        self.regexPattern = regexPattern
        self.regexOptions = options
        self.captures = parser.captures
        self.hasRegexGroups = parser.hasRegexGroups
    }

    private static func regexOptions(
        for component: URLPattern.Component,
        ignoreCase: Bool
    ) -> NSRegularExpression.Options {
        if ignoreCase || component == .protocol || component == .hostname {
            return [.caseInsensitive]
        }
        return []
    }
}

extension CompiledComponentPattern: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.regexPattern == rhs.regexPattern
            && lhs.regexOptions == rhs.regexOptions
            && lhs.captures == rhs.captures
            && lhs.hasRegexGroups == rhs.hasRegexGroups
    }
}

extension CompiledComponentPattern: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(regexPattern)
        hasher.combine(regexOptions.rawValue)
        hasher.combine(captures)
        hasher.combine(hasRegexGroups)
    }
}

/// Metadata describing one capture group in a compiled component pattern.
struct CaptureInfo: Hashable, Sendable, Codable {
    /// The kind of capture produced by the parser.
    enum Kind: Hashable, Sendable, Codable {
        /// A named capture group.
        case named(String)
        /// An unnamed capture group.
        case unnamed
    }

    var kind: Kind
}

// MARK: - Parser

private struct Parser {
    let source: String
    let component: URLPattern.Component
    var index: String.Index
    var captures: [CaptureInfo] = []
    private(set) var hasRegexGroups = false

    /// Creates a parser for one component pattern source string.
    init(source: String, component: URLPattern.Component) {
        self.source = source
        self.component = component
        self.index = source.startIndex
    }

    /// Parses pattern syntax into a regular-expression fragment.
    mutating func parse(until endDelimiter: Character?, disablePathnamePrefixing: Bool) throws
        -> String
    {
        var output = ""

        while index < source.endIndex {
            let character = source[index]

            if let endDelimiter, character == endDelimiter {
                index = source.index(after: index)
                return output
            }

            switch character {
            case "\\":
                output += try parseEscape()
            case "*":
                output += parseWildcard()
                index = source.index(after: index)
            case ":":
                if shouldParseNamedParameter() {
                    output += try parseNamedParameter(
                        currentOutput: &output,
                        disablePathnamePrefixing: disablePathnamePrefixing
                    )
                } else {
                    output += NSRegularExpression.escapedPattern(for: String(character))
                    index = source.index(after: index)
                }
            case "(":
                output += try parseRegexGroup(
                    currentOutput: &output,
                    disablePathnamePrefixing: disablePathnamePrefixing
                )
            case "{":
                index = source.index(after: index)
                let inner = try parse(until: "}", disablePathnamePrefixing: true)
                var groupRegex = "(?:\(inner))"
                if let modifier = parseModifierIfPresent() {
                    groupRegex += modifier
                }
                output += groupRegex
            default:
                output += NSRegularExpression.escapedPattern(for: String(character))
                index = source.index(after: index)
            }
        }

        if endDelimiter != nil {
            throw URLPatternError.invalidPattern("Unterminated group delimiter.")
        }

        return output
    }

    private mutating func parseEscape() throws -> String {
        let backslashIndex = index
        index = source.index(after: index)
        guard index < source.endIndex else {
            throw URLPatternError.invalidPattern(
                "Trailing escape at \(source.distance(from: source.startIndex, to: backslashIndex))."
            )
        }

        let escaped = source[index]
        index = source.index(after: index)
        return NSRegularExpression.escapedPattern(for: String(escaped))
    }

    /// Parses a wildcard token and records its capture metadata.
    private mutating func parseWildcard() -> String {
        captures.append(.init(kind: .unnamed))
        return "([\\s\\S]*)"
    }

    /// Parses a named parameter token, including optional regex and modifiers.
    private mutating func parseNamedParameter(
        currentOutput: inout String,
        disablePathnamePrefixing: Bool
    ) throws -> String {
        index = source.index(after: index)
        let nameStart = index

        while index < source.endIndex {
            let character = source[index]
            if character.isLetter || character.isNumber || character == "_" || character == "-" {
                index = source.index(after: index)
            } else {
                break
            }
        }

        guard nameStart < index else {
            throw URLPatternError.invalidPattern("Expected parameter name after ':'.")
        }

        let rawName = String(source[nameStart..<index])
        var sanitizedName = rawName.map { character -> Character in
            if character.isLetter || character.isNumber || character == "_" {
                return character
            }
            return "_"
        }
        if let first = sanitizedName.first, first.isNumber {
            sanitizedName.insert("_", at: sanitizedName.startIndex)
        }
        let name = String(sanitizedName)

        var innerPattern = component.defaultPattern
        if index < source.endIndex, source[index] == "(" {
            hasRegexGroups = true
            innerPattern = try parseRawRegexBody()
        }

        let modifier = parseModifierIfPresent()
        captures.append(.init(kind: .named(name)))
        return buildCapture(
            name: name,
            innerPattern: innerPattern,
            modifier: modifier,
            currentOutput: &currentOutput,
            disablePathnamePrefixing: disablePathnamePrefixing
        )
    }

    /// Returns whether a `:` token starts a named parameter.
    private func shouldParseNamedParameter() -> Bool {
        let next = source.index(after: index)
        guard next < source.endIndex else {
            return false
        }

        if index > source.startIndex {
            let previous = source[source.index(before: index)]
            if previous == ":" || previous == "[" {
                return false
            }
        }

        let character = source[next]
        return character.isLetter || character.isNumber || character == "_" || character == "-"
    }

    /// Parses an unnamed regex group token and optional modifiers.
    private mutating func parseRegexGroup(
        currentOutput: inout String,
        disablePathnamePrefixing: Bool
    ) throws -> String {
        hasRegexGroups = true
        let innerPattern = try parseRawRegexBody()
        let modifier = parseModifierIfPresent()
        captures.append(.init(kind: .unnamed))
        return buildCapture(
            name: nil,
            innerPattern: innerPattern,
            modifier: modifier,
            currentOutput: &currentOutput,
            disablePathnamePrefixing: disablePathnamePrefixing
        )
    }

    /// Parses a raw regex body enclosed by matching parentheses.
    private mutating func parseRawRegexBody() throws -> String {
        guard index < source.endIndex, source[index] == "(" else {
            throw URLPatternError.invalidPattern("Expected '(' for regex group.")
        }
        index = source.index(after: index)

        var level = 1
        var body = ""
        while index < source.endIndex {
            let character = source[index]

            if character == "\\" {
                body.append(character)
                index = source.index(after: index)
                if index < source.endIndex {
                    body.append(source[index])
                    index = source.index(after: index)
                }
                continue
            }

            if character == "(" {
                level += 1
                body.append(character)
                index = source.index(after: index)
                continue
            }

            if character == ")" {
                level -= 1
                if level == 0 {
                    index = source.index(after: index)
                    return body
                }
                body.append(character)
                index = source.index(after: index)
                continue
            }

            body.append(character)
            index = source.index(after: index)
        }

        throw URLPatternError.invalidPattern("Unterminated regex group.")
    }

    /// Parses and consumes a quantifier modifier when present.
    private mutating func parseModifierIfPresent() -> String? {
        guard index < source.endIndex else {
            return nil
        }

        let character = source[index]
        switch character {
        case "?", "+", "*":
            index = source.index(after: index)
            return String(character)
        default:
            return nil
        }
    }

    /// Builds a capture expression and applies pathname-aware prefix behavior.
    private func buildCapture(
        name: String?,
        innerPattern: String,
        modifier: String?,
        currentOutput: inout String,
        disablePathnamePrefixing: Bool
    ) -> String {
        let captureBody: String
        if let name {
            captureBody = "(?<\(name)>\(innerPattern))"
        } else {
            captureBody = "(\(innerPattern))"
        }

        guard
            component == .pathname,
            disablePathnamePrefixing == false,
            let modifier,
            currentOutput.hasSuffix("/")
        else {
            if let modifier {
                return "\(captureBody)\(modifier)"
            }
            return captureBody
        }

        if currentOutput.hasSuffix("\\/") {
            currentOutput.removeLast(2)
        } else {
            currentOutput.removeLast()
        }
        return "(?:/\(captureBody))\(modifier)"
    }
}

extension URLPattern.Component {
    /// The default inner regex used for this component's captures.
    fileprivate var defaultPattern: String {
        switch self {
        case .pathname:
            return "[^/]+"
        case .hostname:
            return "[^.]+"
        default:
            return "[\\s\\S]+"
        }
    }
}
