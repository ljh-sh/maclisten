import Foundation
import AppKit

var gAppDelegate: MaclistenAppDelegate?

@main
struct Entry {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())

        // Help and locale-only commands do not need the app lifecycle.
        if args.isEmpty || args.contains("--help") || args.contains("-h") || args.first == "locales" {
            do {
                try await runCmd(MaclistenRoot.self, args)
            } catch {
                printJson(["ok": false, "error": error.localizedDescription])
                exit(1)
            }
            return
        }

        await withCheckedContinuation { continuation in
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
            gAppDelegate = MaclistenAppDelegate(args: args) {
                continuation.resume()
            }
            app.delegate = gAppDelegate
            app.run()
        }
    }
}
