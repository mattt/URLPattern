import Foundation

enum URLPatternMatcher {
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
            canonicalInput = try URLPatternCanonicalizer.canonicalMatchURL(url)
            rawInput = url.absoluteString
        case .string(let string, let baseURL):
            canonicalInput = try URLPatternCanonicalizer.canonicalMatchString(
                string, baseURL: baseURL)
            rawInput = string
        case .components(let input):
            canonicalInput = try URLPatternCanonicalizer.canonicalMatchInput(input)
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

        guard
            let protocolResult = match(
                components.compiled(.protocol), against: canonicalInput.protocol),
            let usernameResult = match(
                components.compiled(.username), against: canonicalInput.username),
            let passwordResult = match(
                components.compiled(.password), against: canonicalInput.password),
            let hostnameResult = match(
                components.compiled(.hostname), against: canonicalInput.hostname),
            let portResult = match(components.compiled(.port), against: canonicalInput.port),
            let pathnameResult = match(
                components.compiled(.pathname), against: canonicalInput.pathname),
            let searchResult = match(components.compiled(.search), against: canonicalInput.search),
            let hashResult = match(components.compiled(.hash), against: canonicalInput.hash)
        else {
            return nil
        }

        return URLPattern.Result(
            inputs: [rawInput],
            protocol: protocolResult,
            username: usernameResult,
            password: passwordResult,
            hostname: hostnameResult,
            port: portResult,
            pathname: pathnameResult,
            search: searchResult,
            hash: hashResult
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
