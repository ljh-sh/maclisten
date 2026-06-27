import Foundation

enum MaclistenRoot: Cmd {
    static let meta = CmdMeta(
        name: "maclisten",
        desc: "macOS speech-to-text CLI — lightweight ASR",
        subcmds: [
            "file": FileCmd.self,
            "mic": MicCmd.self,
            "watch": WatchCmd.self,
            "locales": LocalesCmd.self,
            "auth": AuthCmd.self,
            "say": SayCmd.self,
        ],
        run: { p in
            guard let sub = p.arg(0) else {
                printCmdHelp(MaclistenRoot.self)
                return
            }
            var subArgs = p
            if !subArgs.args.isEmpty {
                subArgs.args.removeFirst()
            }
            switch sub {
            case "file":
                try await FileCmd.meta.run?(subArgs)
            case "mic":
                try await MicCmd.meta.run?(subArgs)
            case "watch":
                try await WatchCmd.meta.run?(subArgs)
            case "locales":
                try await LocalesCmd.meta.run?(subArgs)
            case "auth":
                try await AuthCmd.meta.run?(subArgs)
            case "say":
                try await SayCmd.meta.run?(subArgs)
            default:
                cmdError("unknown subcommand: \(sub)")
            }
        }
    )
}
