import Foundation
import Testing
@testable import OpenIslandApp
import OpenIslandCore

struct TerminalJumpTargetResolverTests {
    @Test
    func tmuxCorrectionUsesLiveWarpHostInsteadOfHookEnvironment() {
        let session = AgentSession(
            id: "codex-session",
            title: "Codex · project",
            tool: .codex,
            phase: .running,
            summary: "Working",
            updatedAt: .now,
            jumpTarget: JumpTarget(
                terminalApp: "iTerm",
                workspaceName: "project",
                paneTitle: "codex",
                workingDirectory: "/tmp/project",
                terminalTTY: "ttys005"
            )
        )
        let process = ActiveAgentProcessDiscovery.ProcessSnapshot(
            tool: .codex,
            sessionID: "codex-session",
            workingDirectory: "/tmp/project",
            terminalTTY: "/dev/ttys005",
            terminalApp: "Warp",
            tmuxTarget: "dev:1.1",
            tmuxSocketPath: "/private/tmp/tmux-501/default"
        )

        let corrected = TerminalJumpTargetResolver().correctedTmuxJumpTarget(
            for: session,
            snapshot: .init(
                paneID: "dev:1.1",
                tty: "/dev/ttys005",
                title: "codex project"
            ),
            activeProcesses: [process]
        )

        #expect(corrected?.terminalApp == "Warp")
        #expect(corrected?.terminalTTY == "/dev/ttys005")
        #expect(corrected?.tmuxTarget == "dev:1.1")
        #expect(corrected?.tmuxSocketPath == "/private/tmp/tmux-501/default")
    }
}
