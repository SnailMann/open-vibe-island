import Foundation
import Testing
@testable import OpenIslandCore

/// Verifies cancellation behavior for bridge requests that intentionally wait for user interaction.
/// 验证等待用户交互的 bridge 请求能够随所属进程及时取消。
struct BridgeCommandClientTests {
    @Test
    func cancelledPermissionRequestClosesBridgeConnection() throws {
        let socketURL = BridgeSocketLocation.uniqueTestURL()
        let server = BridgeServer(socketURL: socketURL)
        try server.start()
        defer { server.stop() }

        let payload = ClaudeHookPayload(
            cwd: "/tmp/worktree",
            hookEventName: .permissionRequest,
            sessionID: "cancelled-hook-session",
            toolName: "Bash",
            toolInput: .object(["command": .string("true")])
        )
        var cancellationChecks = 0

        do {
            _ = try BridgeCommandClient(socketURL: socketURL).send(
                .processClaudeHook(payload),
                timeout: 2,
                shouldCancel: {
                    cancellationChecks += 1
                    return cancellationChecks > 1
                }
            )
            Issue.record("Expected the pending bridge request to be cancelled")
        } catch BridgeTransportError.cancelled {
            // Expected: the control connection asks BridgeServer to discard the pending interaction.
        } catch {
            Issue.record("Unexpected bridge error: \(error)")
        }

        #expect(cancellationChecks >= 2)

        for _ in 0..<100 where server.pendingClaudeStateSnapshotForTests().interactionCount != 0 {
            Thread.sleep(forTimeInterval: 0.02)
        }

        #expect(server.pendingClaudeStateSnapshotForTests().interactionCount == 0)
        #expect(server.pendingClaudeStateSnapshotForTests().activeClientCount == 0)
    }
}
