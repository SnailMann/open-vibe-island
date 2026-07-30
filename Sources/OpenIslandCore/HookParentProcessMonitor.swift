import Darwin
import Foundation

/// Tracks the agent process that owns a hook invocation so blocking bridge calls do not outlive it.
/// 跟踪当前 hook 所属的 agent 进程，避免阻塞式 bridge 调用在父进程退出后继续残留。
public struct HookParentProcessMonitor: Sendable {
    /// Claude Code exposes its stable process ID through this hook environment key.
    /// Claude Code 通过该 hook 环境变量提供稳定的主进程 PID。
    public static let claudeProcessIDKey = "CLAUDE_PID"

    /// Process whose lifetime bounds this hook invocation.
    /// 用于约束当前 hook 生命周期的 agent 进程 PID。
    public let processID: pid_t?

    public init(
        environment: [String: String],
        fallbackParentProcessID: pid_t = getppid()
    ) {
        let declaredProcessID = environment[Self.claudeProcessIDKey].flatMap(pid_t.init)
        let resolvedProcessID = declaredProcessID ?? fallbackParentProcessID
        processID = resolvedProcessID > 1 ? resolvedProcessID : nil
    }

    /// Returns true only when the tracked process is known to no longer exist.
    /// 仅在系统明确确认目标进程不存在时返回 true；权限不足等情况保持 fail-open。
    public var hasExited: Bool {
        guard let processID else {
            return false
        }

        if kill(processID, 0) == 0 {
            return false
        }

        return errno == ESRCH
    }
}
