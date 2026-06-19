import Foundation
import AppKit

enum ListenCmd: Cmd {
    static let meta = CmdMeta(
        name: "listen",
        desc: "macOS speech-to-text",
        subcmds: [
            "file": FileCmd.self,
            "mic": MicCmd.self,
            "locales": LocalesCmd.self,
        ]
    )
}

enum FileCmd: Cmd {
    static let meta = CmdMeta(
        name: "file",
        desc: "Transcribe an audio file",
        opts: [
            OptMeta(name: "--locale", type: String.self, desc: "Locale identifier (default: en-US)", `default`: "en-US"),
            OptMeta(name: "--on-device", type: Bool.self, desc: "Require on-device recognition"),
            OptMeta(name: "--json", type: Bool.self, desc: "Output JSON (default)"),
        ],
        args: [ArgMeta(name: "path", desc: "Path to audio file")],
        run: { p in
            guard let path = p.arg(0) else { cmdError("audio file path required") }
            let url = URL(fileURLWithPath: path)
            let locale = p.opt("--locale") as String? ?? "en-US"
            let onDevice = p.opt("--on-device") as Bool? ?? false

            let result = await AsrCtrl().transcribeFile(url: url, locale: locale, onDevice: onDevice)
            printJson(result)
        }
    )
}

enum MicCmd: Cmd {
    static let meta = CmdMeta(
        name: "mic",
        desc: "Transcribe microphone input",
        opts: [
            OptMeta(name: "--locale", type: String.self, desc: "Locale identifier (default: en-US)", `default`: "en-US"),
            OptMeta(name: "--on-device", type: Bool.self, desc: "Require on-device recognition"),
            OptMeta(name: "--timeout", type: Double.self, desc: "Recording timeout in seconds (default: 10.0)", `default`: 10.0),
            OptMeta(name: "--partial", type: Bool.self, desc: "Stream partial results as JSON lines"),
            OptMeta(name: "--auto-stop", type: Bool.self, desc: "Stop when partial text stops changing"),
            OptMeta(name: "--auto-stop-silence", type: Double.self, desc: "Seconds of stable partial text before auto-stop (default: 5.0)", `default`: 5.0),
            OptMeta(name: "--json", type: Bool.self, desc: "Output JSON (default)"),
        ],
        run: { p in
            let locale = p.opt("--locale") as String? ?? "en-US"
            let onDevice = p.opt("--on-device") as Bool? ?? false
            let timeout = p.opt("--timeout") as Double? ?? 10.0
            let partial = p.opt("--partial") as Bool? ?? false
            let autoStop = p.opt("--auto-stop") as Bool? ?? false
            let autoStopSilence = p.opt("--auto-stop-silence") as Double? ?? 5.0

            let result = await AsrCtrl().transcribeMicrophone(
                locale: locale,
                onDevice: onDevice,
                timeout: timeout,
                onPartial: partial ? { text in
                    printJson(["ok": true, "partial": true, "text": text])
                    fflush(stdout)
                } : nil,
                autoStop: autoStop,
                autoStopSilence: autoStopSilence
            )
            printJson(result)
        }
    )
}

enum LocalesCmd: Cmd {
    static let meta = CmdMeta(
        name: "locales",
        desc: "List supported speech recognition locales",
        opts: [
            OptMeta(name: "--json", type: Bool.self, desc: "Output JSON (default)"),
        ],
        run: { p in
            let locales = AsrCtrl.supportedLocales()
            printJson(["ok": true, "count": locales.count, "locales": locales])
        }
    )
}

enum AuthCmd: Cmd {
    static let meta = CmdMeta(
        name: "auth",
        desc: "Open System Settings to grant Speech Recognition / Microphone permissions",
        run: { p in
            let speechURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")!
            let micURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
            NSWorkspace.shared.open(speechURL)
            NSWorkspace.shared.open(micURL)
            printJson([
                "ok": true,
                "message": "Opened System Settings. Grant Speech Recognition (and Microphone for 'mic') to your terminal, then run maclisten again."
            ])
        }
    )
}
