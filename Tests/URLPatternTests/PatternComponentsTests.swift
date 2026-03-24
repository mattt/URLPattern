import Testing

@testable import URLPattern

@Suite("Component Model")
struct PatternComponentsTests {
    @Test
    func hashableAndEquatableBehavior() throws {
        let lhs = try makePattern("/books/:id")
        let rhs = try makePattern("/books/:id")
        let different = try makePattern("/books/:slug")

        #expect(lhs == rhs)
        #expect(lhs != different)
        #expect(lhs.hashValue == rhs.hashValue)
    }

    @Test
    func hasRegExpGroupsTracksRegexUsage() throws {
        let withRegex = try makePattern("/books/:id(\\d+)")
        let withoutRegex = try makePattern("/books/:id")

        #expect(withRegex.hasRegExpGroups)
        #expect(!withoutRegex.hasRegExpGroups)
    }
}
