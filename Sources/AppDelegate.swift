import Foundation
import AppKit

class MaclistenAppDelegate: NSObject, NSApplicationDelegate {
    private let args: [String]
    private let completion: () -> Void

    init(args: [String], completion: @escaping () -> Void) {
        self.args = args
        self.completion = completion
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            do {
                try await runCmd(MaclistenRoot.self, args)
            } catch {
                printJson(["ok": false, "error": error.localizedDescription])
            }
            completion()
        }
    }
}
