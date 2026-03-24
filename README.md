# URLPattern

A Swift implementation of the
[WHATWG URL Pattern API](https://urlpattern.spec.whatwg.org).

Match URLs against patterns with named groups, wildcards,
and component-level control —
using the same syntax defined by the web standard.

## Installation

Add this package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mattt/URLPattern.git", from: "0.1.0")
]
```

## Usage

### Matching URLs

Create a pattern and test whether a URL matches:

```swift
let pattern = try URLPattern("https://example.com/books/:id")
pattern.test("https://example.com/books/123") // true
pattern.test("https://example.com/authors/456") // false
```

### Extracting Groups

Use `exec` to retrieve captured groups from each URL component:

```swift
let pattern = try URLPattern("https://example.com/books/:id")
if let result = try pattern.exec("https://example.com/books/123") {
    print(result.pathname.groups["id"]) // Optional("123")
}
```

### Pattern Syntax

Patterns support named parameters, wildcards, regex groups, and modifiers:

```swift
// Named parameters
try URLPattern("/books/:id")

// Named parameters with regex constraint
try URLPattern("/books/:id(\\d+)")

// Wildcards
try URLPattern("/assets/*")

// Optional segments
try URLPattern("/books/:id?")

// Repeating segments
try URLPattern("/files/:path+")
```

### Component-Level Patterns

Match against individual URL components
using structured `Input`:

```swift
let pattern = try URLPattern([
    "protocol": "https",
    "hostname": "*.example.com",
    "pathname": "/api/*"
])
```

### Base URL Inheritance

Relative patterns inherit unspecified components from a base URL:

```swift
let pattern = try URLPattern("/books/:id", "https://example.com")
pattern.test("https://example.com/books/123") // true
```

### Switch Statements

The `~=` operator enables `switch`-based URL routing:

```swift
let url: URL = ...

switch url {
case URLPattern("https://example.com/books/:id"):
    // handle book
case URLPattern("https://example.com/authors/:id"):
    // handle author
default:
    break
}
```

### Codable

`URLPattern` conforms to `Codable`.
Patterns decode from a plain string or a keyed object:

```json
"/books/:id"
```

```json
{
  "protocol": "https",
  "hostname": "example.com",
  "pathname": "/books/:id",
  "ignoreCase": true
}
```

## License

MIT
