import Foundation
import Testing
@testable import OpenIslandCore

/// Verifies the per-process hook skip environment contract.
/// 验证单次子进程 hook 跳过环境变量协议。
struct HookSkipConfigurationTests {
    /// Accepts common truthy spellings for the preferred Open Island key.
    /// 推荐的新环境变量接受常见真值写法。
    @Test
    func openIslandSkipHooksAcceptsTruthyValues() {
        for value in ["1", "true", "TRUE", "yes", "on", " 1 "] {
            #expect(HookSkipConfiguration.shouldSkipHooks(environment: [
                HookSkipConfiguration.openIslandSkipKey: value,
            ]))
        }
    }

    /// Keeps compatibility with existing Vibe Island-based wrappers.
    /// 保留对已有 Vibe Island wrapper 的兼容。
    @Test
    func legacyVibeIslandSkipAliasIsSupported() {
        #expect(HookSkipConfiguration.shouldSkipHooks(environment: [
            HookSkipConfiguration.legacyVibeIslandSkipKey: "1",
        ]))
    }

    /// Rejects unset or non-truthy values so hooks remain enabled by default.
    /// 未设置或非真值时保持默认启用 hook。
    @Test
    func skipHooksRejectsFalsyOrMissingValues() {
        for value in ["", "0", "false", "no", "off", "random"] {
            #expect(!HookSkipConfiguration.shouldSkipHooks(environment: [
                HookSkipConfiguration.openIslandSkipKey: value,
            ]))
        }

        #expect(!HookSkipConfiguration.shouldSkipHooks(environment: [:]))
    }

    /// Drains stdin even in skip mode so large hook payloads cannot hit a closed pipe.
    /// 跳过 hook 时仍消费 stdin，避免大 payload 写入已关闭管道。
    @Test
    func readHookInputDrainsPayloadBeforeSkipping() {
        var didReadInput = false

        let input = HookSkipConfiguration.readHookInput(
            environment: [HookSkipConfiguration.openIslandSkipKey: "1"],
            reader: {
                didReadInput = true
                return Data("payload".utf8)
            }
        )

        #expect(didReadInput)
        #expect(input == nil)
    }

    /// Returns non-empty stdin unchanged when hooks are enabled.
    /// hook 启用时原样返回非空 stdin。
    @Test
    func readHookInputReturnsPayloadWhenEnabled() {
        let expected = Data("payload".utf8)
        let input = HookSkipConfiguration.readHookInput(
            environment: [:],
            reader: { expected }
        )

        #expect(input == expected)
    }
}
