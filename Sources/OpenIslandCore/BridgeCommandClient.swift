import Darwin
import Foundation

public final class BridgeCommandClient: @unchecked Sendable {
    private let socketURL: URL

    public init(socketURL: URL = BridgeSocketLocation.currentURL()) {
        self.socketURL = socketURL
    }

    public func send(
        _ command: BridgeCommand,
        timeout: TimeInterval = 45,
        shouldCancel: (() -> Bool)? = nil
    ) throws -> BridgeResponse? {
        let fileDescriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fileDescriptor != -1 else {
            throw BridgeTransportError.systemCallFailed("socket", errno)
        }

        defer {
            close(fileDescriptor)
        }

        do {
            try disableSocketSigPipe(fileDescriptor)
            try withUnixSocketAddress(path: socketURL.path) { address, length in
                guard Darwin.connect(fileDescriptor, address, length) != -1 else {
                    throw BridgeTransportError.systemCallFailed("connect", errno)
                }
            }

            // Poll blocking requests in short intervals when their owner can disappear,
            // so an abandoned permission hook releases its bridge connection promptly.
            // 当父进程可能退出时缩短单次读取等待，让废弃的权限 hook 能及时释放 bridge 连接。
            let receiveTimeout = shouldCancel == nil ? timeout : min(timeout, 0.25)
            var receiveTimeoutValue = timeval(
                tv_sec: Int(receiveTimeout),
                tv_usec: Int32((receiveTimeout - floor(receiveTimeout)) * 1_000_000)
            )

            guard setsockopt(
                fileDescriptor,
                SOL_SOCKET,
                SO_RCVTIMEO,
                &receiveTimeoutValue,
                socklen_t(MemoryLayout<timeval>.size)
            ) != -1 else {
                throw BridgeTransportError.systemCallFailed("setsockopt", errno)
            }

            var sendTimeoutValue = timeval(
                tv_sec: Int(timeout),
                tv_usec: Int32((timeout - floor(timeout)) * 1_000_000)
            )

            guard setsockopt(
                fileDescriptor,
                SOL_SOCKET,
                SO_SNDTIMEO,
                &sendTimeoutValue,
                socklen_t(MemoryLayout<timeval>.size)
            ) != -1 else {
                throw BridgeTransportError.systemCallFailed("setsockopt", errno)
            }

            let data = try BridgeCodec.encodeLine(.command(command))
            try writeAll(data, to: fileDescriptor)
        } catch {
            throw error
        }

        let deadline = Date().addingTimeInterval(timeout)
        var buffer = Data()
        var localBuffer = [UInt8](repeating: 0, count: 8_192)

        while true {
            if shouldCancel?() == true {
                notifyCancellation(for: command)
                throw BridgeTransportError.cancelled
            }

            let bytesRead = read(fileDescriptor, &localBuffer, localBuffer.count)

            if bytesRead > 0 {
                buffer.append(localBuffer, count: bytesRead)
                let messages = try BridgeCodec.decodeLines(from: &buffer)

                for message in messages {
                    if case let .response(response) = message {
                        return response
                    }
                }

                continue
            }

            if bytesRead == 0 {
                return nil
            }

            if errno == EAGAIN || errno == EWOULDBLOCK {
                if Date() >= deadline {
                    throw BridgeTransportError.responseTimedOut
                }

                continue
            }

            if errno == EINTR {
                continue
            }

            throw BridgeTransportError.systemCallFailed("read", errno)
        }
    }

    /// Uses a separate one-request connection because bridge clients intentionally send one command per socket.
    /// 使用独立的单请求连接发送取消命令，保持 bridge 现有“一连接一命令”的传输约定。
    private func notifyCancellation(for command: BridgeCommand) {
        guard let sessionID = command.hookSessionID else {
            return
        }

        _ = try? BridgeCommandClient(socketURL: socketURL).send(
            .cancelPendingRequest(sessionID: sessionID),
            timeout: 0.5
        )
    }
}

private extension BridgeCommand {
    /// Session identifier used to cancel a blocking hook request on a separate bridge connection.
    /// 用于通过独立 bridge 连接取消阻塞式 hook 请求的会话标识。
    var hookSessionID: String? {
        switch self {
        case let .processCodexHook(payload):
            payload.sessionID
        case let .processClaudeHook(payload):
            payload.sessionID
        case let .processOpenCodeHook(payload):
            payload.sessionID
        case let .processCursorHook(payload):
            payload.sessionID
        case let .processGeminiHook(payload):
            payload.sessionID
        default:
            nil
        }
    }
}
