@testable import URLPattern

func makePattern(_ value: String, baseURL: String? = nil, options: URLPattern.Options = .init())
    throws
    -> URLPattern
{
    let pattern = value
    return try URLPattern(pattern, baseURL, options: options)
}
