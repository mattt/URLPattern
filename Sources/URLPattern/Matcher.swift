import Foundation

enum PatternMatcher {
    enum Input {
        case url(URL)
        case string(String, baseURL: String?)
        case components(URLPattern.Input)
    }

    static func exec(components: PatternComponents, input: Input) throws -> URLPattern.Result? {
        let canonicalInput: URLPatternParts
        let rawInput: String

        switch input {
        case .url(let url):
            canonicalInput = try PatternCanonicalizer.canonicalMatchURL(url)
            rawInput = url.absoluteString
        case .string(let string, let baseURL):
            canonicalInput = try PatternCanonicalizer.canonicalMatchString(
                string, baseURL: baseURL)
            rawInput = string
        case .components(let input):
            canonicalInput = try PatternCanonicalizer.canonicalMatchInput(input)
            rawInput = [
                input.protocol,
                input.username,
                input.password,
                input.hostname,
                input.port,
                input.pathname,
                input.search,
                input.hash,
            ]
            .compactMap { $0 }
            .joined(separator: "|")
        }

        var results: [URLPattern.Component: URLPattern.ComponentResult] = [:]
        for component in URLPattern.Component.allCases {
            guard
                let result = match(
                    components.compiled(component),
                    against: canonicalInput[component])
            else {
                return nil
            }
            results[component] = result
        }

        return URLPattern.Result(
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

    private static func match(_ compiled: CompiledComponentPattern, against value: String)
        -> URLPattern.ComponentResult?
    {
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

        return URLPattern.ComponentResult(input: value, groups: groups)
    }
}
