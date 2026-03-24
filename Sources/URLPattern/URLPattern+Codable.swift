import Foundation

extension URLPattern: Codable {
    enum CodingKeys: String, CodingKey {
        case `protocol`
        case username
        case password
        case hostname
        case port
        case pathname
        case search
        case hash
        case baseURL
        case ignoreCase
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
            let pattern = try? container.decode(String.self)
        {
            try self.init(pattern)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let input = Input(
            protocol: try container.decodeIfPresent(String.self, forKey: .protocol),
            username: try container.decodeIfPresent(String.self, forKey: .username),
            password: try container.decodeIfPresent(String.self, forKey: .password),
            hostname: try container.decodeIfPresent(String.self, forKey: .hostname),
            port: try container.decodeIfPresent(String.self, forKey: .port),
            pathname: try container.decodeIfPresent(String.self, forKey: .pathname),
            search: try container.decodeIfPresent(String.self, forKey: .search),
            hash: try container.decodeIfPresent(String.self, forKey: .hash),
            baseURL: try container.decodeIfPresent(String.self, forKey: .baseURL)
        )

        let options = Options(
            ignoreCase: try container.decodeIfPresent(Bool.self, forKey: .ignoreCase) ?? false
        )
        try self.init(input, options: options)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.protocol, forKey: .protocol)
        try container.encode(username, forKey: .username)
        try container.encode(password, forKey: .password)
        try container.encode(hostname, forKey: .hostname)
        try container.encode(port, forKey: .port)
        try container.encode(pathname, forKey: .pathname)
        try container.encode(search, forKey: .search)
        try container.encode(hash, forKey: .hash)
        try container.encode(options.ignoreCase, forKey: .ignoreCase)
    }
}
