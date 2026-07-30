import Foundation
import OpenIslandCore

@main
struct OpenIslandHooksCLI {
    private static let interactiveClaudeHookTimeout: TimeInterval = 24 * 60 * 60
    private static let interactiveCodexHookTimeout =
        TimeInterval(CodexHookInstaller.codexPermissionRequestTimeout)

    private enum HookSource: String {
        case codex
        case claude
        case qoder
        case qwen
        case factory
        case droid
        case codebuddy
        case cursor
        case gemini
        case kimi

        var isClaudeFormat: Bool {
            switch self {
            case .claude, .qoder, .qwen, .factory, .droid, .codebuddy, .kimi:
                return true
            case .codex, .cursor, .gemini:
                return false
            }
        }
    }

    static func main() {
        do {
            let environment = ProcessInfo.processInfo.environment
            guard let input = HookSkipConfiguration.readHookInput(
                environment: environment,
                reader: { FileHandle.standardInput.readDataToEndOfFile() }
            ) else {
                return
            }

            let arguments = Array(CommandLine.arguments.dropFirst())
            let source = hookSource(arguments: arguments)
            let sourceString = rawSourceString(arguments: arguments)
            let decoder = JSONDecoder()
            let client = BridgeCommandClient(socketURL: BridgeSocketLocation.currentURL())
            // Permission hooks may wait for user input for hours; stop waiting as soon as their agent process exits.
            // 权限 hook 可能等待用户操作数小时；所属 agent 进程退出后立即取消，避免产生孤儿进程。
            let parentProcessMonitor = HookParentProcessMonitor(environment: environment)
            let shouldCancel = { parentProcessMonitor.hasExited }

            switch source {
            case .codex:
                let payload = try decoder
                    .decode(CodexHookPayload.self, from: input)
                    .withRuntimeContext(environment: ProcessInfo.processInfo.environment)

                let timeout = payload.hookEventName == .permissionRequest
                    ? interactiveCodexHookTimeout
                    : 45

                guard let response = try? client.send(
                    .processCodexHook(payload),
                    timeout: timeout,
                    shouldCancel: shouldCancel
                ) else {
                    logStderr("bridge unavailable for codex hook (\(payload.hookEventName.rawValue))")
                    return
                }

                if let output = try CodexHookOutputEncoder.standardOutput(for: response) {
                    FileHandle.standardOutput.write(output)
                }
            case .claude, .qoder, .qwen, .factory, .droid, .codebuddy, .kimi:
                var payload = try decoder
                    .decode(ClaudeHookPayload.self, from: input)
                    .withRuntimeContext(environment: ProcessInfo.processInfo.environment)
                payload.hookSource = sourceString

                let timeout = payload.hookEventName == .permissionRequest
                    ? interactiveClaudeHookTimeout
                    : 45

                guard let response = try? client.send(
                    .processClaudeHook(payload),
                    timeout: timeout,
                    shouldCancel: shouldCancel
                ) else {
                    logStderr("bridge unavailable for claude hook (\(payload.hookEventName.rawValue))")
                    return
                }

                if let output = try ClaudeHookOutputEncoder.standardOutput(for: response) {
                    FileHandle.standardOutput.write(output)
                }
            case .cursor:
                let payload = try decoder.decode(CursorHookPayload.self, from: input)

                let timeout: TimeInterval = payload.isBlockingHook
                    ? Self.interactiveClaudeHookTimeout
                    : 45

                guard let response = try? client.send(
                    .processCursorHook(payload),
                    timeout: timeout,
                    shouldCancel: shouldCancel
                ) else {
                    return
                }

                if case let .cursorHookDirective(directive) = response {
                    let encoder = JSONEncoder()
                    let output = try encoder.encode(directive)
                    FileHandle.standardOutput.write(output)
                    FileHandle.standardOutput.write(Data("\n".utf8))
                }
            case .gemini:
                let payload = try decoder
                    .decode(GeminiHookPayload.self, from: input)
                    .withRuntimeContext(environment: ProcessInfo.processInfo.environment)

                _ = try? client.send(
                    .processGeminiHook(payload),
                    timeout: 45,
                    shouldCancel: shouldCancel
                )
            }
        } catch {
            // Hooks should fail open so the CLI continues working even if the bridge is unavailable.
            logStderr("hook failed: \(error)")
        }
    }

    private static func logStderr(_ message: String) {
        guard let data = "[OpenIslandHooks] \(message)\n".data(using: .utf8) else { return }
        SafeFileDescriptorWriter.write(data)
    }

    private static func hookSource(arguments: [String]) -> HookSource {
        var index = 0
        while index < arguments.count {
            if arguments[index] == "--source", index + 1 < arguments.count {
                return HookSource(rawValue: arguments[index + 1]) ?? .codex
            }

            index += 1
        }

        return .codex
    }

    private static func rawSourceString(arguments: [String]) -> String? {
        var index = 0
        while index < arguments.count {
            if arguments[index] == "--source", index + 1 < arguments.count {
                return arguments[index + 1]
            }

            index += 1
        }

        return nil
    }
}
