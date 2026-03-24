import Testing

@testable import URLPattern

@Test
func protocolAndHostnameAreCaseInsensitiveByDefault() throws {
    let pattern = try URLPattern("https://Example.COM/books/:id")
    #expect(pattern.test("https://example.com/books/123"))
    #expect(pattern.test("HTTPS://EXAMPLE.COM/books/123"))
}

@Test
func pathnameIsCaseSensitiveByDefault() throws {
    let pattern = try URLPattern("https://example.com/books/:id")
    #expect(pattern.test("https://example.com/books/123"))
    #expect(!pattern.test("https://example.com/Books/123"))
}

@Test
func ignoreCaseOptionAppliesToAllComponents() throws {
    let pattern = try URLPattern(
        "https://example.com/books/:id",
        options: .init(ignoreCase: true)
    )

    #expect(pattern.test("HTTPS://EXAMPLE.COM/Books/123"))
}
