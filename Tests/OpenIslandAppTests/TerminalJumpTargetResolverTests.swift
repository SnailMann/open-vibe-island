import Foundation
import Testing
@testable import OpenIslandApp
import OpenIslandCore

struct TerminalJumpTargetResolverTests {
    @Test
    func liveTmuxProcessCreatesWarpTargetForRestoredSessionWithoutHookContext() {
        let session = AgentSession(
            id: "restored-codex-session",
            title: "Codex · project",
            tool: .codex,
            phase: .running,
            summary: "Working",
            updatedAt: .now
        )
        let process = ActiveAgentProcessDiscovery.ProcessSnapshot(
            tool: .codex,
            sessionID: "restored-codex-session",
            workingDirectory: "/tmp/project",
            terminalTTY: "/dev/ttys005",
            terminalApp: "Warp",
            tmuxTarget: "dev:1.1",
            tmuxSocketPath: "/private/tmp/tmux-501/default"
        )
        let snapshot = TerminalJumpTargetResolver.TmuxPaneSnapshot(
            paneID: "dev:1.1",
            tty: "/dev/ttys005",
            title: "codex project"
        )
        let resolver = TerminalJumpTargetResolver()

        let matches = resolver.matchTmuxSnapshots(
            [snapshot],
            to: [session],
            activeProcesses: [process]
        )
        let corrected = resolver.correctedTmuxJumpTarget(
            for: session,
            snapshot: snapshot,
            activeProcesses: [process]
        )

        #expect(matches[session.id]?.paneID == snapshot.paneID)
        #expect(matches[session.id]?.tty == snapshot.tty)
        #expect(corrected?.terminalApp == "Warp")
        #expect(corrected?.workingDirectory == "/tmp/project")
        #expect(corrected?.workspaceName == "project")
        #expect(corrected?.tmuxTarget == "dev:1.1")
    }

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
