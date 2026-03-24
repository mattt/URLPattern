import Foundation

enum PatternStringParser {
    static func parsePatternString(_ value: String, baseURL: String?) -> URLPattern.Input {
        let baseParsed: URLPattern.Input
        if value.contains("://") {
            baseParsed = parseLooseURLString(value)
        } else {
            baseParsed = URLPattern.Input(pathname: value)
        }
        var parsed = baseParsed
        parsed.baseURL = baseURL
        return parsed
    }

    static func parseLooseURLString(_ value: String) -> URLPattern.Input {
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

            return URLPattern.Input(
                protocol: scheme,
                username: authorityParts.username,
                password: authorityParts.password,
                hostname: authorityParts.hostname,
                port: authorityParts.port,
                pathname: path.isEmpty ? "/" : path,
                search: search,
                hash: hash
            )
        }

        return URLPattern.Input(
            pathname: working.isEmpty ? "/" : working,
            search: search,
            hash: hash
        )
    }

    private static func parseAuthority(_ authority: String) -> (
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

    private static func firstUnescapedCharacter(_ character: Character, in string: String) -> String
        .Index?
    {
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
}
