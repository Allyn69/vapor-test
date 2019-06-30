public struct ClientRequest {
    public var method: HTTPMethod
    public var url: URI
    public var headers: HTTPHeaders
    public var body: ByteBuffer?

    public init(method: HTTPMethod = .GET, url: URI = "/", headers: HTTPHeaders = [:], body: ByteBuffer? = nil) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }

    // MARK: Content

    private struct _URLQueryContainer: URLQueryContainer {
        var url: URI

        func decode<D>(_ decodable: D.Type, using decoder: URLQueryDecoder) throws -> D
            where D: Decodable
        {
            return try decoder.decode(D.self, from: self.url)
        }

        mutating func encode<E>(_ encodable: E, using encoder: URLQueryEncoder) throws
            where E: Encodable
        {
            try encoder.encode(encodable, to: &self.url)
        }
    }

    public var query: URLQueryContainer {
        get {
            return _URLQueryContainer(url: self.url)
        }
        set {
            self.url = (newValue as! _URLQueryContainer).url
        }
    }

    private struct _ContentContainer: ContentContainer {
        var body: ByteBuffer?
        var headers: HTTPHeaders

        var contentType: HTTPMediaType? {
            return self.headers.contentType
        }

        mutating func encode<E>(_ encodable: E, using encoder: ContentEncoder) throws where E : Encodable {
            var body = ByteBufferAllocator().buffer(capacity: 0)
            try encoder.encode(encodable, to: &body, headers: &self.headers)
            self.body = body
        }

        func decode<D>(_ decodable: D.Type, using decoder: ContentDecoder) throws -> D where D : Decodable {
            guard let body = self.body else {
                throw Abort(.lengthRequired)
            }
            return try decoder.decode(D.self, from: body, headers: self.headers)
        }
    }

    public var content: ContentContainer {
        get {
            return _ContentContainer(body: self.body, headers: self.headers)
        }
        set {
            let container = (newValue as! _ContentContainer)
            self.body = container.body
            self.headers = container.headers
        }
    }
}
