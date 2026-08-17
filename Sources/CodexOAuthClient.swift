import AppKit
import CryptoKit
import Foundation
import Network
import Security

struct CodexOAuthCredentials: Codable, Sendable {
    let access: String
    let refresh: String
    let expires: TimeInterval
    let accountId: String

    var needsRefresh: Bool {
        Date().timeIntervalSince1970 > expires - 60
    }
}

final class CodexOAuthClient {
    private let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    private let authorizeURL = URL(string: "https://auth.openai.com/oauth/authorize")!
    private let tokenURL: URL
    private let redirectURI = "http://localhost:1455/auth/callback"
    private let scope = "openid profile email offline_access"
    private let originator = "codex_cli"
    private let session: URLSession

    init(session: URLSession = .shared, tokenURL: URL? = nil) {
        self.session = session
        self.tokenURL = tokenURL ?? URL(string: "https://auth.openai.com/oauth/token")!
    }

    func login() async throws -> CodexOAuthCredentials {
        let verifier = try randomBase64URL(byteCount: 32)
        let challenge = codeChallenge(for: verifier)
        let state = try randomBase64URL(byteCount: 24)

        var components = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "id_token_add_organizations", value: "true"),
            URLQueryItem(name: "codex_cli_simplified_flow", value: "true"),
            URLQueryItem(name: "originator", value: originator)
        ]

        guard let url = components.url else {
            throw AppError.configuration("无法生成登录链接。")
        }

        let callbackServer = try LocalOAuthCallbackServer(expectedState: state)
        try callbackServer.start()
        let codeTask = Task {
            try await callbackServer.waitForCode()
        }

        let opened = await MainActor.run {
            NSWorkspace.shared.open(url)
        }
        if !opened {
            callbackServer.fail(AppError.configuration("无法打开浏览器进行登录，请重试。"))
        }

        let code = try await codeTask.value
        return try await exchangeAuthorizationCode(code: code, verifier: verifier)
    }

    func refresh(_ credentials: CodexOAuthCredentials) async throws -> CodexOAuthCredentials {
        let params = [
            "grant_type": "refresh_token",
            "refresh_token": credentials.refresh,
            "client_id": clientID
        ]

        // 刷新响应里 refresh_token 是可选字段（RFC 6749 §5.1）；
        // 服务端不回传时沿用旧的。
        return try await exchange(params: params, fallbackRefreshToken: credentials.refresh)
    }

    private func exchangeAuthorizationCode(code: String, verifier: String) async throws -> CodexOAuthCredentials {
        let params = [
            "grant_type": "authorization_code",
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "redirect_uri": redirectURI
        ]

        return try await exchange(params: params)
    }

    private func exchange(params: [String: String], fallbackRefreshToken: String? = nil) async throws -> CodexOAuthCredentials {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody(params)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AppError.network(error.localizedDescription)
        }

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 200
        return try Self.parseTokenResponse(data: data, statusCode: statusCode, fallbackRefreshToken: fallbackRefreshToken)
    }

    static func parseTokenResponse(
        data: Data,
        statusCode: Int,
        fallbackRefreshToken: String?
    ) throws -> CodexOAuthCredentials {
        if !(200..<300).contains(statusCode) {
            throw tokenResponseError(data: data, statusCode: statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String,
              let expiresNumber = json["expires_in"] as? NSNumber,
              let refresh = (json["refresh_token"] as? String) ?? fallbackRefreshToken else {
            throw AppError.response("登录响应缺少必要凭证字段。")
        }

        guard let accountId = accountId(from: access) else {
            throw AppError.response("无法从登录凭证中读取账号 ID。")
        }

        return CodexOAuthCredentials(
            access: access,
            refresh: refresh,
            expires: Date().timeIntervalSince1970 + expiresNumber.doubleValue,
            accountId: accountId
        )
    }

    private static func tokenResponseError(data: Data, statusCode: Int) -> AppError {
        // refresh token 被吊销/已轮换失效时刷新重试无意义，必须重新登录。
        // 实测该端点的错误体是嵌套对象 {"error":{"code":"token_expired",...}}，
        // 同时兼容标准 OAuth 的扁平 {"error":"invalid_grant"}。
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let flatCode = json["error"] as? String
            let nestedCode = (json["error"] as? [String: Any])?["code"] as? String
            let code = nestedCode ?? flatCode
            if let code, ["invalid_grant", "token_expired", "invalid_token", "refresh_token_expired"].contains(code) {
                return .authExpired("ChatGPT 登录已失效，请重新登录。")
            }
        }
        let text = String(data: data, encoding: .utf8) ?? "HTTP \(statusCode)"
        return .response("登录凭证交换失败：\(text)")
    }
}

private final class LocalOAuthCallbackServer: @unchecked Sendable {
    private let expectedState: String
    private let queue = DispatchQueue(label: "CatGPT.CodexOAuth")
    private let listener: NWListener
    private var continuation: CheckedContinuation<String, Error>?
    private var pendingResult: Result<String, Error>?
    private var completed = false
    // 跟踪已 accept 的连接，finish 时一并取消，不遗留半开套接字。
    private var connections: [ObjectIdentifier: NWConnection] = [:]

    init(expectedState: String) throws {
        self.expectedState = expectedState
        guard let port = NWEndpoint.Port(rawValue: 1455) else {
            throw AppError.configuration("登录回调端口无效。")
        }
        // 只监听本机回环地址，避免局域网内其他主机连到回调端口。
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: port)
        params.allowLocalEndpointReuse = true
        listener = try NWListener(using: params)
    }

    func start() throws {
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            if case .failed(let error) = state {
                if case .posix(let code) = error, code == .EADDRINUSE {
                    self.finish(.failure(AppError.network(
                        "登录回调端口 1455 被占用：可能有 codex login 正在进行，请先结束它再重试。"
                    )))
                } else {
                    self.finish(.failure(AppError.network("登录回调服务启动失败：\(error.localizedDescription)")))
                }
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }

        listener.start(queue: queue)

        // 兜底超时：用户关掉浏览器不完成授权时，不能让 continuation 永久挂起、
        // isLoggingIn 卡死、端口被永久占用。
        queue.asyncAfter(deadline: .now() + 300) { [weak self] in
            self?.finish(.failure(AppError.network("登录超时（5 分钟内未完成授权），请重试。")))
        }
    }

    func fail(_ error: Error) {
        finish(.failure(error))
    }

    func waitForCode() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if let pending = self.pendingResult {
                    self.pendingResult = nil
                    continuation.resume(with: pending)
                } else {
                    self.continuation = continuation
                }
            }
        }
    }

    private func handle(_ connection: NWConnection) {
        connections[ObjectIdentifier(connection)] = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .cancelled, .failed:
                self?.connections.removeValue(forKey: ObjectIdentifier(connection))
            default:
                break
            }
        }
        connection.start(queue: queue)
        receiveRequest(connection, buffer: Data())
    }

    /// 循环接收直到请求头完整（出现空行）。浏览器的 speculative 预连接、
    /// 分包到达的请求都不能终结整个登录——只有拿到合法授权码才 finish。
    private func receiveRequest(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data {
                buffer.append(data)
            }

            let headerComplete = buffer.range(of: Data("\r\n\r\n".utf8)) != nil
                || buffer.range(of: Data("\n\n".utf8)) != nil
            guard headerComplete else {
                if error != nil || isComplete || buffer.count > 64 * 1024 {
                    // 预连接/异常连接：放弃这条连接，继续等待真正的回调。
                    connection.cancel()
                } else {
                    self.receiveRequest(connection, buffer: buffer)
                }
                return
            }

            self.process(buffer, on: connection)
        }
    }

    private func process(_ data: Data, on connection: NWConnection) {
        guard let request = String(data: data, encoding: .utf8),
              let firstLine = request
                  .replacingOccurrences(of: "\r\n", with: "\n")
                  .components(separatedBy: "\n")
                  .first else {
            respond(connection, status: 400, message: "登录回调无效。")
            return
        }

        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2,
              let url = URL(string: String(parts[1]), relativeTo: URL(string: "http://localhost")) else {
            respond(connection, status: 400, message: "登录回调地址无效。")
            return
        }

        guard url.path == "/auth/callback" else {
            respond(connection, status: 404, message: "没有找到登录回调路径。")
            return
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let query = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        // state 不匹配（旧标签页重放等）只拒绝该请求，不终结登录。
        guard query["state"] == expectedState else {
            respond(connection, status: 400, message: "登录状态校验失败，请回到应用重新发起登录。")
            return
        }

        guard let code = query["code"], !code.isEmpty else {
            respond(connection, status: 400, message: "缺少登录授权码。")
            return
        }

        respond(connection, status: 200, message: "登录完成，可以关闭这个窗口。")
        finish(.success(code))
    }

    private func respond(_ connection: NWConnection, status: Int, message: String) {
        let reason = status == 200 ? "OK" : "Error"
        let body = """
        <!doctype html><html><head><meta charset="utf-8"><title>屏幕 Codex</title></head>
        <body style="font:15px -apple-system, BlinkMacSystemFont, sans-serif; padding:32px;">\(message)</body></html>
        """
        let bodyData = Data(body.utf8)
        let header = "HTTP/1.1 \(status) \(reason)\r\n" +
            "Content-Type: text/html; charset=utf-8\r\n" +
            "Content-Length: \(bodyData.count)\r\n" +
            "Connection: close\r\n\r\n"
        var response = Data(header.utf8)
        response.append(bodyData)
        // 从跟踪表移除：这条连接由下面的 send 完成回调负责在响应刷完后取消，
        // 不能让随后的 finish() 抢先 cancel 它、把还没发完的响应体截断。
        connections.removeValue(forKey: ObjectIdentifier(connection))
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func finish(_ result: Result<String, Error>) {
        queue.async {
            guard !self.completed else { return }
            self.completed = true
            self.listener.cancel()
            // 取消所有仍存活的连接（含浏览器不发数据的预连接），不留半开套接字。
            self.connections.values.forEach { $0.cancel() }
            self.connections.removeAll()
            if let continuation = self.continuation {
                self.continuation = nil
                continuation.resume(with: result)
            } else {
                self.pendingResult = result
            }
        }
    }
}

private func randomBase64URL(byteCount: Int) throws -> String {
    var bytes = [UInt8](repeating: 0, count: byteCount)
    let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    guard status == errSecSuccess else {
        throw AppError.configuration("无法生成安全随机数。")
    }
    return Data(bytes).base64URLEncodedString()
}

private func codeChallenge(for verifier: String) -> String {
    let digest = SHA256.hash(data: Data(verifier.utf8))
    return Data(digest).base64URLEncodedString()
}

private func formBody(_ params: [String: String]) -> Data {
    let body = params
        .map { key, value in
            "\(escapeForm(key))=\(escapeForm(value))"
        }
        .joined(separator: "&")
    return Data(body.utf8)
}

private func escapeForm(_ value: String) -> String {
    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove(charactersIn: "&+=")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
}

private func accountId(from token: String) -> String? {
    let parts = token.split(separator: ".")
    guard parts.count == 3,
          let data = Data(base64URLEncoded: String(parts[1])),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let auth = json["https://api.openai.com/auth"] as? [String: Any],
          let accountId = auth["chatgpt_account_id"] as? String,
          !accountId.isEmpty else {
        return nil
    }
    return accountId
}

extension Data {
    init?(base64URLEncoded string: String) {
        var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        self.init(base64Encoded: base64)
    }

    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
