import XCTest
@testable import maclisten

/// Shared capture sink for the probe command (file scope so the static `meta` initializer
/// does not need to capture a local).
private final class LocaleBox { var locales: [String]? }
private let box = LocaleBox()

/// Minimal command surface to exercise the option parser (`runCmd`) without needing Speech
/// Recognition permission or audio.
private enum ProbeCmd: Cmd {
    static let meta = CmdMeta(
        name: "probe",
        opts: [OptMeta(name: "--locale", type: String.self, multiple: true)],
        run: { p in box.locales = p.opt("--locale") as [String]? }
    )
}

final class maclistenTests: XCTestCase {
    func testPlaceholder() {
        XCTAssertTrue(true)
    }

    func testRepeatedLocaleOptAccumulates() async throws {
        box.locales = nil
        try await runCmd(ProbeCmd.self, ["--locale", "zh-CN", "--locale", "en-US", "--locale", "ja-JP"])
        XCTAssertEqual(box.locales, ["zh-CN", "en-US", "ja-JP"])
    }

    func testSingleLocaleOptIsOneElementArray() async throws {
        box.locales = nil
        try await runCmd(ProbeCmd.self, ["--locale", "zh-CN"])
        XCTAssertEqual(box.locales, ["zh-CN"])
    }

    func testNoLocaleOptIsNil() async throws {
        box.locales = nil
        try await runCmd(ProbeCmd.self, [])
        XCTAssertNil(box.locales)
    }
}
