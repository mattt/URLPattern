import Testing

@testable import URLPattern

@Test
func namedParameterAndRegexGroupSyntax() throws {
    let named = try URLPattern("/books/:id(\\d+)")
    #expect(named.test("https://example.com/books/123"))
    #expect(!named.test("https://example.com/books/abc"))
    #expect(named.hasRegExpGroups)
}

@Test
func wildcardAndGroupDelimiterSyntax() throws {
    let wildcard = try URLPattern("/assets/*")
    #expect(wildcard.test("https://example.com/assets/a/b/c.png"))

    let optionalSlash = try URLPattern("/books{/}?")
    #expect(optionalSlash.test("https://example.com/books"))
    #expect(optionalSlash.test("https://example.com/books/"))
}

@Test
func optionalAndRepeatingModifiers() throws {
    let optional = try URLPattern("/books/:id?")
    #expect(optional.test("https://example.com/books"))
    #expect(optional.test("https://example.com/books/1"))
    #expect(!optional.test("https://example.com/books/"))

    let repeating = try URLPattern("/books/:id+")
    #expect(repeating.test("https://example.com/books/1"))
    #expect(repeating.test("https://example.com/books/1/2/3"))
    #expect(!repeating.test("https://example.com/books"))
}
