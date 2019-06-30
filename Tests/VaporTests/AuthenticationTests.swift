import XCTVapor

final class AuthenticationTests: XCTestCase {
    func testBearerAuthenticator() throws {
        struct Test: Authenticatable {
            var name: String
        }

        struct TestAuthenticator: BearerAuthenticator {
            typealias User = Test

            func authenticate(bearer: BearerAuthorization) -> EventLoopFuture<Test?> {
                guard bearer.token == "test" else {
                    return EmbeddedEventLoop().makeSucceededFuture(nil)
                }
                let test = Test(name: "Vapor")
                return EmbeddedEventLoop().makeSucceededFuture(test)
            }
        }

        let app = Application.create(routes: { r, c in
            r.grouped([
                TestAuthenticator().middleware(), Test.guardMiddleware()
            ]).get("test") { req -> String in
                return try req.requireAuthenticated(Test.self).name
            }
        })
        defer { app.shutdown() }

        try app.testable().inMemory()
            .test(.GET, "/test") { res in
                XCTAssertEqual(res.status, .unauthorized)
            }
            .test(.GET, "/test", headers: ["Authorization": "Bearer test"]) { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.body.string, "Vapor")
            }
    }

    func testBasicAuthenticator() throws {
        struct Test: Authenticatable {
            var name: String
        }

        struct TestAuthenticator: BasicAuthenticator {
            typealias User = Test

            func authenticate(basic: BasicAuthorization) -> EventLoopFuture<Test?> {
                guard basic.username == "test" && basic.password == "secret" else {
                    return EmbeddedEventLoop().makeSucceededFuture(nil)
                }
                let test = Test(name: "Vapor")
                return EmbeddedEventLoop().makeSucceededFuture(test)
            }
        }

        let app = Application.create(routes: { r, c in
            r.grouped([
                TestAuthenticator().middleware(), Test.guardMiddleware()
            ]).get("test") { req -> String in
                return try req.requireAuthenticated(Test.self).name
            }
        })
        defer { app.shutdown() }

        let basic = "test:secret".data(using: .utf8)!.base64EncodedString()
        try app.testable().inMemory()
            .test(.GET, "/test") { res in
                XCTAssertEqual(res.status, .unauthorized)
            }
            .test(.GET, "/test", headers: ["Authorization": "Basic \(basic)"]) { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.body.string, "Vapor")
        }
    }

    func testSessionAuthentication() throws {
        struct Test: Authenticatable, SessionAuthenticatable {
            var sessionID: String? {
                return self.name
            }
            var name: String
        }

        struct TestBearerAuthenticator: BearerAuthenticator {
            typealias User = Test

            func authenticate(bearer: BearerAuthorization) -> EventLoopFuture<Test?> {
                guard bearer.token == "test" else {
                    return EmbeddedEventLoop().makeSucceededFuture(nil)
                }
                let test = Test(name: "Vapor")
                return EmbeddedEventLoop().makeSucceededFuture(test)
            }
        }

        struct TestSessionAuthenticator: SessionAuthenticator {
            typealias User = Test

            func resolve(sessionID: String) -> EventLoopFuture<Test?> {
                let test = Test(name: sessionID)
                return EmbeddedEventLoop().makeSucceededFuture(test)
            }
        }

        let app = Application.create(routes: { r, c in
            try r.grouped([
                c.make(SessionsMiddleware.self),
                TestSessionAuthenticator().middleware(),
                TestBearerAuthenticator().middleware(),
                Test.guardMiddleware(),
            ]).get("test") { req -> String in
                return try req.requireAuthenticated(Test.self).name
            }
        })
        defer { app.shutdown() }

        var sessionCookie: HTTPCookies.Value?
        try app.testable().inMemory()
            .test(.GET, "/test") { res in
                XCTAssertEqual(res.status, .unauthorized)
                XCTAssertNil(res.headers.firstValue(name: .setCookie))
            }
            .test(.GET, "/test", headers: ["Authorization": "Bearer test"]) { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.body.string, "Vapor")
                if
                    let cookies = HTTPCookies.parse(setCookieHeaders: res.headers[.setCookie]),
                    let cookie = cookies["vapor-session"]
                {
                    sessionCookie = cookie
                } else {
                    XCTFail("No set cookie header")
                }
            }
            .test(.GET, "/test", headers: ["Cookie": sessionCookie!.serialize(name: "vapor-session")]) { res in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.body.string, "Vapor")
                XCTAssertNotNil(res.headers.firstValue(name: .setCookie))
            }
    }
}
