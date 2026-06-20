import Foundation
import AppKit

/// Common language / region shortcuts for `--locale`.
///
/// Each entry `--<key>` is equivalent to `--locale <value>`.
struct LocaleShortcuts {
    static let map: [String: String] = [
        "ar": "ar-SA",
        "ca": "ca-ES",
        "cs": "cs-CZ",
        "da": "da-DK",
        "de": "de-DE",
        "el": "el-GR",
        "en": "en-US",
        "es": "es-ES",
        "fi": "fi-FI",
        "fr": "fr-FR",
        "he": "he-IL",
        "hi": "hi-IN",
        "hr": "hr-HR",
        "hu": "hu-HU",
        "id": "id-ID",
        "it": "it-IT",
        "ja": "ja-JP",
        "ko": "ko-KR",
        "ms": "ms-MY",
        "nb": "nb-NO",
        "nl": "nl-NL",
        "pl": "pl-PL",
        "pt": "pt-BR",
        "ro": "ro-RO",
        "ru": "ru-RU",
        "sk": "sk-SK",
        "sv": "sv-SE",
        "th": "th-TH",
        "tr": "tr-TR",
        "uk": "uk-UA",
        "vi": "vi-VN",
        "cn": "zh-CN",
        "hk": "zh-HK",
        "tw": "zh-TW",
        "us": "en-US",
        "gb": "en-GB",
        "au": "en-AU",
    ]

    static var options: [OptMeta] {
        map.sorted { $0.key < $1.key }.map { (key, locale) in
            OptMeta(name: "--\(key)", type: Bool.self, desc: "Shortcut for --locale \(locale)")
        }
    }
}

private let localeOptions: [OptMeta] = [
    OptMeta(name: "--locale", type: String.self, desc: "Locale identifier (default: $MACLISTEN_LOCALE, $LANG, or en-US)", `default`: "en-US"),
] + LocaleShortcuts.options

/// Determine the default locale from the environment.
///
/// Priority:
/// 1. `MACLISTEN_LOCALE`
/// 2. `LANG` (e.g. `fr_FR.UTF-8` → `fr-FR`)
/// 3. `en-US`
private func defaultLocale() -> String {
    let env = ProcessInfo.processInfo.environment
    if let v = env["MACLISTEN_LOCALE"], !v.isEmpty {
        return v
    }
    if let lang = env["LANG"], !lang.isEmpty, lang != "C", lang != "POSIX" {
        let base = lang.components(separatedBy: ".").first ?? lang
        let normalized = base.replacingOccurrences(of: "_", with: "-")
        if normalized.contains("-") {
            return normalized
        }
    }
    return "en-US"
}

private func resolveLocale(_ p: ParsedCmd) -> String {
    for (flag, locale) in LocaleShortcuts.map {
        if p.opt("--\(flag)") as Bool? ?? false {
            return locale
        }
    }
    return p.opt("--locale") as String? ?? defaultLocale()
}

enum ListenCmd: Cmd {
    static let meta = CmdMeta(
        name: "listen",
        desc: "macOS speech-to-text",
        subcmds: [
            "file": FileCmd.self,
            "mic": MicCmd.self,
            "watch": WatchCmd.self,
            "locales": LocalesCmd.self,
            "auth": AuthCmd.self,
        ]
    )
}

enum FileCmd: Cmd {
    static let meta = CmdMeta(
        name: "file",
        desc: "Transcribe an audio file",
        opts: localeOptions + [
            OptMeta(name: "--on-device", type: Bool.self, desc: "Require on-device recognition"),
            OptMeta(name: "--json", type: Bool.self, desc: "Output JSON (default)"),
        ],
        args: [ArgMeta(name: "path", desc: "Path to audio file")],
        run: { p in
            guard let path = p.arg(0) else { cmdError("audio file path required") }
            let url = URL(fileURLWithPath: path)
            let locale = resolveLocale(p)
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
        opts: localeOptions + [
            OptMeta(name: "--on-device", type: Bool.self, desc: "Require on-device recognition"),
            OptMeta(name: "--timeout", type: Double.self, desc: "Recording timeout in seconds (default: 10.0)", `default`: 10.0),
            OptMeta(name: "--partial", type: Bool.self, desc: "Stream partial results as JSON lines"),
            OptMeta(name: "--auto-stop", type: Bool.self, desc: "Stop when partial text stops changing"),
            OptMeta(name: "--auto-stop-silence", type: Double.self, desc: "Seconds of stable partial text before auto-stop (default: 5.0)", `default`: 5.0),
            OptMeta(name: "--output", type: String.self, desc: "Also save microphone audio to this file (WAV, 16kHz, 16-bit, mono)"),
            OptMeta(name: "--json", type: Bool.self, desc: "Output JSON (default)"),
        ],
        run: { p in
            let locale = resolveLocale(p)
            let onDevice = p.opt("--on-device") as Bool? ?? false
            let timeout = p.opt("--timeout") as Double? ?? 10.0
            let partial = p.opt("--partial") as Bool? ?? false
            let autoStop = p.opt("--auto-stop") as Bool? ?? false
            let autoStopSilence = p.opt("--auto-stop-silence") as Double? ?? 5.0
            let output = p.opt("--output") as String?
            let outputURL = output.map { URL(fileURLWithPath: $0) }

            let result = await AsrCtrl().transcribeMicrophone(
                locale: locale,
                onDevice: onDevice,
                timeout: timeout,
                onPartial: partial ? { text in
                    printJson(["ok": true, "partial": true, "text": text])
                    fflush(stdout)
                } : nil,
                autoStop: autoStop,
                autoStopSilence: autoStopSilence,
                outputURL: outputURL
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

enum WatchCmd: Cmd {
    static let meta = CmdMeta(
        name: "watch",
        desc: "Continuously listen for voice keywords / commands (restarts recognition automatically)",
        opts: localeOptions + [
            OptMeta(name: "--on-device", type: Bool.self, desc: "Require on-device recognition"),
            OptMeta(name: "--keyword", type: String.self, desc: "Only emit segments containing this keyword"),
            OptMeta(name: "--output", type: String.self, desc: "Also save microphone audio to this file (WAV, 16kHz, 16-bit, mono)"),
            OptMeta(name: "--partial", type: Bool.self, desc: "Stream partial results as JSON lines"),
            OptMeta(name: "--json", type: Bool.self, desc: "Output final summary JSON (default)"),
        ],
        run: { p in
            let locale = resolveLocale(p)
            let onDevice = p.opt("--on-device") as Bool? ?? false
            let keyword = p.opt("--keyword") as String?
            let output = p.opt("--output") as String?
            let outputURL = output.map { URL(fileURLWithPath: $0) }
            let partial = p.opt("--partial") as Bool? ?? false
            let json = p.opt("--json") as Bool? ?? true

            let ctrl = WatchCtrl()
            let result = await ctrl.watch(
                locale: locale,
                onDevice: onDevice,
                keyword: keyword,
                onPartial: partial ? { text in
                    printJson(["ok": true, "partial": true, "text": text])
                    fflush(stdout)
                } : nil,
                onSegment: { text in
                    printJson(["ok": true, "segment": text])
                    fflush(stdout)
                },
                outputURL: outputURL
            )
            if json {
                printJson(result)
            }
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
