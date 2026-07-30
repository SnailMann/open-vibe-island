import Darwin
import Testing
@testable import OpenIslandCore

/// Verifies that hook bridge waits are bounded by the owning agent process lifetime.
/// 验证 hook bridge 等待不会超过所属 agent 进程的生命周期。
struct HookParentProcessMonitorTests {
    @Test
    func declaredClaudeProcessIsPreferredAndRecognizedAsAlive() {
        let monitor = HookParentProcessMonitor(
            environment: [HookParentProcessMonitor.claudeProcessIDKey: "\(getpid())"],
            fallbackParentProcessID: Int32.max
        )

        #expect(monitor.processID == getpid())
        #expect(!monitor.hasExited)
    }

    @Test
    func missingProcessIsRecognizedAsExited() {
        let monitor = HookParentProcessMonitor(
            environment: [HookParentProcessMonitor.claudeProcessIDKey: "\(Int32.max)"],
            fallbackParentProcessID: getpid()
        )

        #expect(monitor.hasExited)
    }

    @Test
    func invalidDeclaredProcessFallsBackToDirectParent() {
        let monitor = HookParentProcessMonitor(
            environment: [HookParentProcessMonitor.claudeProcessIDKey: "invalid"],
            fallbackParentProcessID: getpid()
        )

        #expect(monitor.processID == getpid())
        #expect(!monitor.hasExited)
    }
}
