import Testing

@testable import URLPattern

@Suite("Pattern Syntax")
struct SyntaxTests {
    @Test
    func namedParameterAndRegexGroupSyntax() throws {
        let named = try makePattern("/books/:id(\\d+)")
        #expect(named.test("https://example.com/books/123"))
        #expect(!named.test("https://example.com/books/abc"))
        #expect(named.hasRegExpGroups)
    }

    @Test
    func wildcardAndGroupDelimiterSyntax() throws {
        let wildcard = try makePattern("/assets/*")
        #expect(wildcard.test("https://example.com/assets/a/b/c.png"))

        let optionalSlash = try makePattern("/books{/}?")
        #expect(optionalSlash.test("https://example.com/books"))
        #expect(optionalSlash.test("https://example.com/books/"))
    }

    @Test
    func optionalAndRepeatingModifiers() throws {
        let optional = try makePattern("/books/:id?")
        #expect(optional.test("https://example.com/books"))
        #expect(optional.test("https://example.com/books/1"))
        #expect(!optional.test("https://example.com/books/"))

        let repeating = try makePattern("/books/:id+")
        #expect(repeating.test("https://example.com/books/1"))
        #expect(repeating.test("https://example.com/books/1/2/3"))
        #expect(!repeating.test("https://example.com/books"))
    }

    @Test
    func parserErrorBranchesThrow() throws {
        #expect(throws: URLPatternError.self) { try makePattern("/books/\\") }
        #expect(throws: URLPatternError.self) { try makePattern("/books/{abc") }
        #expect(throws: URLPatternError.self) { try makePattern("/books/(abc") }
    }

    @Test
    func regexCompilationErrorsThrow() throws {
        #expect(throws: URLPatternError.self) { try makePattern("/books/([)") }
    }
}
