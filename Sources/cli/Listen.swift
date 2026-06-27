import Foundation
import AppKit
import AVFoundation

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
    OptMeta(
        name: "--locale",
        type: String.self,
        desc: "Locale identifier, repeatable (default: $MACLISTEN_LOCALE, $LANG, or en-US). On `file`, pass 2+ to auto-pick the highest-confidence result",
        multiple: true
    ),
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

/// Collect every locale the user asked for on `file`: repeated `--locale` values plus any
/// `--<lang>` shortcut flags present. `--locale` values come first (in given order), then
/// shortcuts in alphabetical order. Dedup preserves first occurrence. Returns `[]` when
/// nothing was specified.
private func resolveLocales(_ p: ParsedCmd) -> [String] {
    var seen = Set<String>()
    var list: [String] = []
    func add(_ loc: String) {
        if !seen.contains(loc) {
            seen.insert(loc)
            list.append(loc)
        }
    }
    if let arr = p.opt("--locale") as [String]? {
        arr.forEach(add)
    }
    for (key, locale) in LocaleShortcuts.map.sorted(by: { $0.key < $1.key }) {
        if p.opt("--\(key)") as Bool? ?? false {
            add(locale)
        }
    }
    return list
}

/// Resolve a single locale for `mic` / `watch` (shortcut flags take precedence, then the
/// first `--locale` value, then the environment default).
private func resolveLocale(_ p: ParsedCmd) -> String {
    for (key, locale) in LocaleShortcuts.map.sorted(by: { $0.key < $1.key }) {
        if p.opt("--\(key)") as Bool? ?? false {
            return locale
        }
    }
    if let arr = p.opt("--locale") as [String]?, let first = arr.first {
        return first
    }
    return defaultLocale()
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
            "say": SayCmd.self,
        ]
    )
}

enum FileCmd: Cmd {
    static let meta = CmdMeta(
        name: "file",
        desc: "Transcribe an audio file; pass 2+ locales (repeatable --locale or --cn --en ...) to auto-pick the best-confidence result",
        opts: localeOptions + [
            OptMeta(name: "--on-device", type: Bool.self, desc: "Require on-device recognition"),
            OptMeta(name: "--no-pick", type: Bool.self, desc: "With 2+ locales, emit one JSON line per locale instead of picking the best"),
            OptMeta(name: "--segments", type: Bool.self, desc: "Include per-segment {text, confidence, start, duration} in output"),
            OptMeta(name: "--json", type: Bool.self, desc: "Output JSON (default)"),
        ],
        args: [ArgMeta(name: "path", desc: "Path to audio file — any AVFoundation format: wav, m4a, mp3, aac, caf, aiff")],
        run: { p in
            guard let path = p.arg(0) else { cmdError("audio file path required") }
            let url = URL(fileURLWithPath: path)
            let locales = resolveLocales(p)
            let onDevice = p.opt("--on-device") as Bool? ?? false
            let noPick = p.opt("--no-pick") as Bool? ?? false
            let includeSegments = p.opt("--segments") as Bool? ?? false

            let ctrl = await AsrCtrl()
            if locales.count >= 2 && noPick {
                // Auth is global — fail once instead of once per locale.
                if let authErr = AsrCtrl.speechAuthorizationError() {
                    printJson(["ok": false, "error": authErr])
                    return
                }
                // One compact JSON line per locale, in order — for an agent / jq to judge.
                for loc in locales {
                    let r = await ctrl.transcribeFile(
                        url: url, locale: loc, onDevice: onDevice, includeSegments: includeSegments
                    )
                    printJson(r)
                    fflush(stdout)
                }
            } else if locales.count >= 2 {
                let r = await ctrl.transcribeFileBest(
                    url: url, locales: locales, onDevice: onDevice, includeSegments: includeSegments
                )
                printJson(r)
            } else {
                let loc = locales.first ?? defaultLocale()
                let r = await ctrl.transcribeFile(
                    url: url, locale: loc, onDevice: onDevice, includeSegments: includeSegments
                )
                printJson(r)
            }
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

/// Text-to-speech using NSSpeechSynthesizer (works in CLI).
enum SayCmd: Cmd {
    static let meta = CmdMeta(
        name: "say",
        desc: "Text-to-speech using NSSpeechSynthesizer (better than built-in 'say')",
        opts: localeOptions + [
            OptMeta(name: "--rate", type: Double.self, desc: "Speech rate (words per minute, default: 200)", `default`: 200.0),
            OptMeta(name: "--pitch", type: Double.self, desc: "Pitch multiplier (0.5-2.0, default: 1.0)", `default`: 1.0),
            OptMeta(name: "--volume", type: Double.self, desc: "Volume (0.0-1.0, default: 1.0)", `default`: 1.0),
            OptMeta(name: "--wait", type: Bool.self, desc: "Wait for speech to finish before exiting (default: true)"),
            OptMeta(name: "--json", type: Bool.self, desc: "Output JSON (default)"),
        ],
        args: [ArgMeta(name: "text", desc: "Text to speak", required: false)],
        run: { p in
            let locale = resolveLocale(p)
            let rate = p.opt("--rate") as Double? ?? 200.0
            let pitch = p.opt("--pitch") as Double? ?? 1.0
            let volume = p.opt("--volume") as Double? ?? 1.0
            let wait = p.opt("--wait") as Bool? ?? true

            // If no text provided, read from stdin
            var text: String? = p.arg(0)
            if text == nil || text?.isEmpty == true {
                text = p.opt("--text") as String?
            }
            if text == nil || text?.isEmpty == true {
                if let stdin = readLine(), !stdin.isEmpty {
                    text = stdin
                }
            }

            guard let text = text, !text.isEmpty else {
                cmdError("text required")
            }

            // Auto-detect and speak each segment
            let segments = detectLanguages(text)

            for segment in segments {
                let synthesizer = NSSpeechSynthesizer()
                if let voice = findBestVoice(for: segment.locale) {
                    synthesizer.setVoice(voice)
                }
                synthesizer.startSpeaking(segment.text)
                while synthesizer.isSpeaking {
                    usleep(50_000)
                }
            }
            printJson(["ok": true, "locale": locale, "text": text])
        }
    )
}

/// Auto-detect language segments in text.
private func detectLanguages(_ text: String) -> [(locale: String, text: String)] {
    var segments: [(locale: String, text: String)] = []
    var currentText = ""
    var currentLang = ""

    for char in text {
        let lang = detectLanguage(char)

        if lang != currentLang && !currentText.isEmpty {
            let trimmed = currentText.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                segments.append((locale: currentLang, text: trimmed))
            }
            currentText = ""
        }
        currentText.append(char)
        currentLang = lang
    }

    let trimmed = currentText.trimmingCharacters(in: .whitespaces)
    if !trimmed.isEmpty && currentLang != "" {
        segments.append((locale: currentLang, text: trimmed))
    }

    // If only one segment, return as-is
    if segments.count <= 1 {
        return [("", text)]
    }

    return segments
}

/// Detect language of a single character.
private func detectLanguage(_ char: Character) -> String {
    guard let scalar = char.unicodeScalars.first else { return "en-US" }
    let code = scalar.value

    // Chinese
    if (0x4E00...0x9FFF).contains(code) || (0x3400...0x4DBF).contains(code) {
        return "zh-CN"
    }
    // Japanese hiragana
    if (0x3040...0x309F).contains(code) {
        return "ja-JP"
    }
    // Japanese katakana
    if (0x30A0...0x30FF).contains(code) {
        return "ja-JP"
    }
    // Korean
    if (0xAC00...0xD7AF).contains(code) || (0x1100...0x11FF).contains(code) {
        return "ko-KR"
    }
    // Cyrillic
    if (0x0400...0x04FF).contains(code) {
        return "ru-RU"
    }
    // Arabic
    if (0x0600...0x06FF).contains(code) {
        return "ar-SA"
    }
    // Thai
    if (0x0E00...0x0E7F).contains(code) {
        return "th-TH"
    }
    // Latin (English/European)
    if (0x0000...0x024F).contains(code) {
        return "en-US"
    }
    // Default to English
    return "en-US"
}

/// Parse mixed-language text using {{locale:text}} syntax.
private func parseMixedLanguage(_ text: String) -> [(locale: String, text: String)] {
    var segments: [(locale: String, text: String)] = []
    var searchStart = text.startIndex

    while searchStart < text.endIndex {
        // Find {{
        guard let openStart = text.range(of: "{{", range: searchStart..<text.endIndex)?.lowerBound else {
            break
        }
        // Find : after {{
        guard let colonPos = text.range(of: ":", range: text.index(after: openStart)..<text.endIndex)?.lowerBound else {
            break
        }
        // Find }}
        guard let closeEnd = text.range(of: "}}", range: colonPos..<text.endIndex)?.lowerBound else {
            break
        }

        let locale = String(text[text.index(after: openStart)..<colonPos])
        let segmentText = String(text[text.index(after: colonPos)..<closeEnd])

        segments.append((locale: locale, text: segmentText))
        searchStart = text.index(after: closeEnd)
    }

    // If no segments found, return the whole text as single segment
    if segments.isEmpty {
        return [("", text)]
    }

    return segments
}

/// Find the best voice for a locale.
private func findBestVoice(for locale: String) -> NSSpeechSynthesizer.VoiceName? {
    let allVoices = NSSpeechSynthesizer.availableVoices

    // Chinese: use Tingting (female)
    if locale == "zh-CN" {
        for voice in allVoices {
            if voice.rawValue == "com.apple.voice.compact.zh-CN.Tingting" {
                return voice
            }
        }
    }

    // English: use Samantha (system default female)
    if locale == "en-US" || locale == "en-GB" || locale == "en-AU" {
        // Try Samantha first (compact, reliable)
        for voice in allVoices {
            if voice.rawValue == "com.apple.voice.compact.en-US.Samantha" {
                return voice
            }
        }
        // Fallback to Flo
        for voice in allVoices {
            if voice.rawValue.contains("Flo") && voice.rawValue.contains("en-US") {
                return voice
            }
        }
    }

    // Japanese: use Kyoko (compact female)
    if locale == "ja-JP" {
        for voice in allVoices {
            if voice.rawValue == "com.apple.voice.compact.ja-JP.Kyoko" {
                return voice
            }
        }
    }

    // Korean: use Yuna (compact female)
    if locale == "ko-KR" {
        for voice in allVoices {
            if voice.rawValue == "com.apple.voice.compact.ko-KR.Yuna" {
                return voice
            }
        }
    }

    // Use default voice for other locales
    return nil
}
