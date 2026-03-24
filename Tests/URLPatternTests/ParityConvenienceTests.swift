import Foundation
import Testing

@testable import URLPattern

@Suite("Parity Conveniences")
struct ParityConvenienceTests {
    @Test
    func codableSupportsStringAndObjectForms() throws {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        let stringPattern = try decoder.decode(URLPattern.self, from: Data(#""/books/:id""#.utf8))
        #expect(stringPattern.test("https://example.com/books/1"))

        let objectJSON = """
            {
              "pathname": "/books/:id",
              "hostname": "example.com",
              "ignoreCase": true
            }
            """
        let objectPattern = try decoder.decode(URLPattern.self, from: Data(objectJSON.utf8))
        #expect(objectPattern.test("https://EXAMPLE.COM/books/1"))

        let encoded = try encoder.encode(objectPattern)
        let roundTrip = try decoder.decode(URLPattern.self, from: encoded)
        #expect(roundTrip.test("https://example.com/books/1"))
    }

    @Test
    func stringLiteralAndOperatorConveniences() throws {
        let literalPattern: URLPattern = "/items/:id"
        #expect(literalPattern.test("https://example.com/items/99"))

        let urlPattern = try makePattern("/posts/:id")
        let url = try #require(URL(string: "https://example.com/posts/123"))
        #expect(urlPattern ~= url)
        #expect(urlPattern ~= "https://example.com/posts/123")
    }

    @Test
    func urlPatternErrorLocalizedDescriptions() {
        #expect(URLPatternError.invalidPattern("x").errorDescription != nil)
        #expect(URLPatternError.invalidBaseURL("x").errorDescription != nil)
        #expect(URLPatternError.invalidURLInput("x").errorDescription != nil)
        #expect(URLPatternError.invalidComponent("x").errorDescription != nil)
        #expect(URLPatternError.unsupported("x").errorDescription != nil)
        #expect(URLPatternError.regexCompilationFailed("x").errorDescription != nil)
    }
}
