import Foundation

enum URLPatternComponent: String, CaseIterable, Sendable, Codable {
    case `protocol`
    case username
    case password
    case hostname
    case port
    case pathname
    case search
    case hash
}

struct CaptureInfo: Hashable, Sendable, Codable {
    enum Kind: Hashable, Sendable, Codable {
        case named(String)
        case unnamed
    }

    var kind: Kind
}

struct CompiledComponentPattern: Sendable {
    var original: String
    var regexPattern: String
    var regexOptions: NSRegularExpression.Options
    var captures: [CaptureInfo]
    var hasRegExpGroups: Bool

    var regex: NSRegularExpression {
        // Safe because instances are only created through compile().
        try! NSRegularExpression(pattern: regexPattern, options: regexOptions)
    }
}

enum URLPatternCompiler {
    struct CompileOptions: Hashable, Sendable {
        var ignoreCase: Bool
    }

    static func compile(
        component: URLPatternComponent,
        pattern: String,
        options: CompileOptions
    ) throws -> CompiledComponentPattern {
        if pattern == "*" {
            let regexPattern = "^([\\s\\S]*)$"
            return CompiledComponentPattern(
                original: pattern,
                regexPattern: regexPattern,
                regexOptions: regexOptions(for: component, ignoreCase: options.ignoreCase),
                captures: [.init(kind: .unnamed)],
                hasRegExpGroups: false
            )
        }

        var parser = Parser(
            source: pattern,
            component: component
        )
        let body = try parser.parse(until: nil, disablePathnamePrefixing: false)
        let regexPattern = "^\(body)$"

        // Ensure regex is valid now and throw a typed error.
        do {
            _ = try NSRegularExpression(
                pattern: regexPattern,
                options: regexOptions(for: component, ignoreCase: options.ignoreCase)
            )
        } catch {
            throw URLPatternError.regexCompilationFailed(error.localizedDescription)
        }

        return CompiledComponentPattern(
            original: pattern,
            regexPattern: regexPattern,
            regexOptions: regexOptions(for: component, ignoreCase: options.ignoreCase),
            captures: parser.captures,
            hasRegExpGroups: parser.hasRegExpGroups
        )
    }

    private static func regexOptions(for component: URLPatternComponent, ignoreCase: Bool)
        -> NSRegularExpression.Options
    {
        if ignoreCase || component == .protocol || component == .hostname {
            return [.caseInsensitive]
        }

        return []
    }
}

private struct Parser {
    let source: String
    let component: URLPatternComponent
    var index: String.Index
    var captures: [CaptureInfo] = []
    private(set) var hasRegExpGroups = false

    init(source: String, component: URLPatternComponent) {
        self.source = source
        self.component = component
        self.index = source.startIndex
    }

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

    private mutating func parseWildcard() -> String {
        captures.append(.init(kind: .unnamed))
        return "([\\s\\S]*)"
    }

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
        let name = sanitizeCaptureName(rawName)

        var innerPattern = defaultPatternForComponent(component)
        if index < source.endIndex, source[index] == "(" {
            hasRegExpGroups = true
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

    private mutating func parseRegexGroup(
        currentOutput: inout String,
        disablePathnamePrefixing: Bool
    ) throws -> String {
        hasRegExpGroups = true
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

private func defaultPatternForComponent(_ component: URLPatternComponent) -> String {
    switch component {
    case .pathname:
        return "[^/]+"
    case .hostname:
        return "[^.]+"
    default:
        return "[\\s\\S]+"
    }
}

private func sanitizeCaptureName(_ name: String) -> String {
    var sanitized = name.map { character -> Character in
        if character.isLetter || character.isNumber || character == "_" {
            return character
        }
        return "_"
    }

    if let first = sanitized.first, first.isNumber {
        sanitized.insert("_", at: sanitized.startIndex)
    }

    return String(sanitized)
}
