extension HTTPClient: Client {
    public var eventLoop: EventLoop {
        return self.eventLoopGroup.next()
    }

    public func send(_ client: ClientRequest) -> EventLoopFuture<ClientResponse> {
        do {
            let request = try HTTPClient.Request(
                url: URL(string: client.url.string)!,
                version: .init(major: 1, minor: 1),
                method: client.method,
                headers: client.headers, body: client.body.flatMap { .byteBuffer($0) }
            )
            return self.execute(request: request).map { response in
                let client = ClientResponse(
                    status: response.status,
                    headers: response.headers,
                    body: response.body
                )
                return client
            }
        } catch {
            return self.eventLoop.makeFailedFuture(error)
        }
    }
}
