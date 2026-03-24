import Testing

@testable import URLPattern

@Suite("Core URLPattern")
struct URLPatternTests {
    @Test
    func basicPathnameMatch() throws {
        let pattern = try makePattern("/books/:id")
        let result = try #require(try pattern.exec("https://example.com/books/123"))

        #expect(result.pathname.groups["id"] == "123")
        #expect(pattern.test("https://example.com/books/123"))
        #expect(!pattern.test("https://example.com/books"))
    }
}
