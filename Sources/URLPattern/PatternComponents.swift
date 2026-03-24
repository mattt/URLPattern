import Foundation

struct PatternComponents: Hashable, Sendable {
    var patterns: URLPatternParts
    var options: URLPattern.Options
    var hasRegexGroups: Bool

    private var compiled: [URLPattern.Component: CompiledComponentPattern]

    init(patternString: String, baseURL: String?, options: URLPattern.Options) throws {
        let parsed = PatternStringParser.parsePatternString(patternString, baseURL: baseURL)
        try self.init(patternInput: parsed, options: options)
    }

    init(patternInput: URLPattern.Input, options: URLPattern.Options) throws {
        let parts = try PatternCanonicalizer.canonicalPatternInput(patternInput)
        self.patterns = parts
        self.options = options

        var compiled: [URLPattern.Component: CompiledComponentPattern] = [:]
        var hasRegexGroups = false
        for component in URLPattern.Component.allCases {
            let result = try PatternCompiler.compile(
                component: component,
                pattern: parts[component],
                ignoreCase: options.ignoreCase
            )
            compiled[component] = result
            hasRegexGroups = hasRegexGroups || result.hasRegexGroups
        }

        self.compiled = compiled
        self.hasRegexGroups = hasRegexGroups
    }

    func compiled(_ component: URLPattern.Component) -> CompiledComponentPattern {
        compiled[component]!
    }
}
