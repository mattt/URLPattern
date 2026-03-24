import Foundation

extension URLPattern {
    func matchAll(
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
