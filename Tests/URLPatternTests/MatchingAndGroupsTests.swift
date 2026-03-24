import Testing

@testable import URLPattern

@Test
func execReturnsNamedGroups() throws {
    let pattern = try URLPattern("/users/:userId/orders/:orderId")
    let result = try #require(try pattern.exec("https://example.com/users/42/orders/abc"))

    #expect(result.pathname.input == "/users/42/orders/abc")
    #expect(result.pathname.groups["userId"] == "42")
    #expect(result.pathname.groups["orderId"] == "abc")
}

@Test
func execReturnsUnnamedGroupsForWildcardsAndRegexGroups() throws {
    let wildcard = try URLPattern("/files/*")
    let wildcardResult = try #require(try wildcard.exec("https://example.com/files/a/b.txt"))
    #expect(wildcardResult.pathname.groups["0"] == "a/b.txt")

    let regex = try URLPattern("/product/(foo|bar)")
    let regexResult = try #require(try regex.exec("https://example.com/product/foo"))
    #expect(regexResult.pathname.groups["0"] == "foo")
}

@Test
func trailingSlashIsNotMatchedByDefault() throws {
    let patternNoSlash = try URLPattern("/books")
    #expect(patternNoSlash.test("https://example.com/books"))
    #expect(!patternNoSlash.test("https://example.com/books/"))

    let patternWithSlash = try URLPattern("/books/")
    #expect(!patternWithSlash.test("https://example.com/books"))
    #expect(patternWithSlash.test("https://example.com/books/"))
}
