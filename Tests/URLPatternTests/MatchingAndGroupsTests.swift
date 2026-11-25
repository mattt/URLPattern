import Testing

@testable import URLPattern

@Suite("Matching And Groups")
struct MatchingAndGroupsTests {
    @Test
    func execReturnsNamedGroups() throws {
        let pattern = try makePattern("/users/:userId/orders/:orderId")
        let result = try #require(try pattern.exec("https://example.com/users/42/orders/abc"))

        #expect(result.pathname.input == "/users/42/orders/abc")
        #expect(result.pathname.groups["userId"] == "42")
        #expect(result.pathname.groups["orderId"] == "abc")
    }

    @Test
    func execReturnsUnnamedGroupsForWildcardsAndRegexGroups() throws {
        let wildcard = try makePattern("/files/*")
        let wildcardResult = try #require(try wildcard.exec("https://example.com/files/a/b.txt"))
        #expect(wildcardResult.pathname.groups["0"] == "a/b.txt")

        let regex = try makePattern("/product/(foo|bar)")
        let regexResult = try #require(try regex.exec("https://example.com/product/foo"))
        #expect(regexResult.pathname.groups["0"] == "foo")
    }

    @Test
    func unnamedGroupKeepsItsIndexWhenAnEarlierGroupIsAbsent() throws {
        let pattern = try URLPattern(.init(pathname: "/files/(draft)?/(.+)"))
        let published = try #require(try pattern.exec("https://example.test/files/report"))
        let draft = try #require(try pattern.exec("https://example.test/files/draft/report"))

        #expect(published.pathname.groups == ["1": "report"])
        #expect(draft.pathname.groups == ["0": "draft", "1": "report"])
    }

    @Test
    func trailingSlashIsNotMatchedByDefault() throws {
        let patternNoSlash = try makePattern("/books")
        #expect(patternNoSlash.test("https://example.com/books"))
        #expect(!patternNoSlash.test("https://example.com/books/"))

        let patternWithSlash = try makePattern("/books/")
        #expect(!patternWithSlash.test("https://example.com/books"))
        #expect(patternWithSlash.test("https://example.com/books/"))
    }

    @Test
    func relativeStringInputResolvesAgainstBaseURL() throws {
        let pattern = try makePattern("https://example.com/foo/*")
        #expect(pattern.test("bar", "https://example.com/foo/"))
    }
}
