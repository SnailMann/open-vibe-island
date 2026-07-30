import Foundation

/// Centralizes the per-process hook skip environment contract.
/// 集中管理“单次子进程跳过 hook”的环境变量协议。
public enum HookSkipConfiguration {
    /// Preferred Open Island environment key for disabling hooks in this process.
    /// Open Island 推荐使用的当前进程 hook 跳过开关。
    public static let openIslandSkipKey = "OPEN_ISLAND_SKIP_HOOKS"
    /// Compatibility alias used by existing Vibe Island integrations.
    /// 兼容已有 Vibe Island 集成使用的旧开关。
    public static let legacyVibeIslandSkipKey = "VIBE_ISLAND_SKIP"

    /// Returns true when the provided environment explicitly requests hook no-op mode.
    /// 当传入环境显式要求跳过 hook 时返回 true。
    public static func shouldSkipHooks(environment: [String: String]) -> Bool {
        isTruthy(environment[openIslandSkipKey])
            || isTruthy(environment[legacyVibeIslandSkipKey])
    }

    /// Reads the complete hook payload before honoring skip mode so the agent never writes into a closed pipe.
    /// 即使当前进程要求跳过 hook，也先消费完整 stdin，避免 agent 写入已关闭管道而触发 EPIPE。
    public static func readHookInput(
        environment: [String: String],
        reader: () -> Data
    ) -> Data? {
        let input = reader()
        guard !shouldSkipHooks(environment: environment), !input.isEmpty else {
            return nil
        }

        return input
    }

    /// Interprets common shell-friendly truthy values and treats everything else as false.
    /// 只接受常见 shell 友好的真值，其它值都按 false 处理。
    private static func isTruthy(_ value: String?) -> Bool {
        guard let value else { return false }
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }
}
