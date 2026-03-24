import Testing

@testable import URLPattern

@Suite("Component Inheritance")
struct ComponentInheritanceTests {
    @Test
    func patternInheritsFromBaseURLForLessSpecificComponents() throws {
        let pattern = try URLPattern(
            .init(pathname: "/foo/*", baseURL: "https://example.com/base")
        )

        #expect(pattern.protocol == "https")
        #expect(pattern.hostname == "example.com")
        #expect(pattern.pathname == "/foo/*")
        #expect(pattern.search == "*")
        #expect(pattern.hash == "*")
    }

    @Test
    func credentialsDoNotInheritFromBaseURL() throws {
        let pattern = try URLPattern(
            .init(pathname: "/foo/*", baseURL: "https://user:pass@example.com/base")
        )

        #expect(pattern.username == "*")
        #expect(pattern.password == "*")
    }

    @Test
    func objectInputCanInheritForMatching() throws {
        let pattern = try URLPattern(
            .init(hostname: "example.com", pathname: "/foo/*")
        )

        let input = URLPattern.Input(
            pathname: "/foo/bar",
            baseURL: "https://example.com/base"
        )

        #expect(pattern.test(input))
    }

    @Test
    func invalidBaseURLThrows() throws {
        #expect(throws: URLPatternError.self) {
            try URLPattern(.init(pathname: "/foo/*", baseURL: ""))
        }
    }
}
