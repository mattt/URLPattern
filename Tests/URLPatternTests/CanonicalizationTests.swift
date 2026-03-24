import Testing

@testable import URLPattern

@Suite("Canonicalization")
struct CanonicalizationTests {
    @Test
    func protocolAndHostnameAreCaseInsensitiveByDefault() throws {
        let pattern = try makePattern("https://Example.COM/books/:id")
        #expect(pattern.test("https://example.com/books/123"))
        #expect(pattern.test("HTTPS://EXAMPLE.COM/books/123"))
    }

    @Test
    func pathnameIsCaseSensitiveByDefault() throws {
        let pattern = try makePattern("https://example.com/books/:id")
        #expect(pattern.test("https://example.com/books/123"))
        #expect(!pattern.test("https://example.com/Books/123"))
    }

    @Test
    func ignoreCaseOptionAppliesToAllComponents() throws {
        let pattern = try makePattern(
            "https://example.com/books/:id",
            options: .init(ignoreCase: true)
        )

        #expect(pattern.test("HTTPS://EXAMPLE.COM/Books/123"))
    }

    @Test
    func protocolSearchHashAndEmptyPathNormalize() throws {
        let pattern = try URLPattern(
            .init(
                protocol: "https:", hostname: "example.com", pathname: "", search: "?q=1",
                hash: "#top")
        )

        #expect(pattern.protocol == "https")
        #expect(pattern.pathname == "/")
        #expect(pattern.search == "q=1")
        #expect(pattern.hash == "top")
    }

    @Test
    func looseParsingHandlesAuthorityVariants() throws {
        let ipv6 = try makePattern("https://[::1]:8080/path")
        #expect(ipv6.hostname == "[::1]")
        #expect(ipv6.port == "8080")
        #expect(ipv6.test("https://[::1]:8080/path"))

        let withUserInfo = try makePattern("https://user:pass@example.com/path")
        #expect(withUserInfo.username == "user")
        #expect(withUserInfo.password == "pass")
        #expect(withUserInfo.test("https://user:pass@example.com/path"))
    }
}
