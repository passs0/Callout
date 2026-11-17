import AppKit
import AVFoundation
import CoreServices
import NaturalLanguage

enum SearchEngine: String, CaseIterable, Identifiable {
    case google = "Google"
    case duckDuckGo = "DuckDuckGo"
    case bing = "Bing"
    case naver = "Naver"

    var id: String { rawValue }

    func searchURL(for query: String) -> URL? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        switch self {
        case .google:
            return URL(string: "https://www.google.com/search?q=\(encoded)")
        case .duckDuckGo:
            return URL(string: "https://duckduckgo.com/?q=\(encoded)")
        case .bing:
            return URL(string: "https://www.bing.com/search?q=\(encoded)")
        case .naver:
            return URL(string: "https://search.naver.com/search.naver?query=\(encoded)")
        }
    }
}

enum TextActionKind: String, CaseIterable, Identifiable {
    case copy = "Copy"
    case lookUp = "Look Up"
    case translate = "Translate"
    case find = "Find"
    case searchWeb = "Search Web"
    case speak = "Speak"
    case spell = "Spell"
    case copyLinkWithHighlight = "Copy Link with Highlight"
    case share = "Share..."
    case newQuickNote = "New Quick Note"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .copy: return "doc.on.doc"
        case .lookUp: return "info.circle"
        case .translate: return "translate"
        case .find: return "magnifyingglass"
        case .searchWeb: return "magnifyingglass"
        case .speak: return "play"
        case .spell: return "play"
        case .copyLinkWithHighlight: return "text.quote"
        case .share: return "square.and.arrow.up"
        case .newQuickNote: return "note.text.badge.plus"
        }
    }
}

@MainActor
final class SpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechManager()
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggleSpeak(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = detectVoice(for: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func spellOut(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let voice = detectVoice(for: trimmed)
        isSpeaking = true
        for scalar in trimmed {
            let charString = String(scalar)
            let utterance = AVSpeechUtterance(string: charString == " " ? "space" : charString)
            utterance.voice = voice
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
            utterance.postUtteranceDelay = 0.12
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    private func detectVoice(for text: String) -> AVSpeechSynthesisVoice? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        if let lang = recognizer.dominantLanguage {
            return AVSpeechSynthesisVoice(language: lang.rawValue)
        }
        return AVSpeechSynthesisVoice(language: Locale.current.identifier)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if !self.synthesizer.isSpeaking {
                self.isSpeaking = false
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.isSpeaking = false
        }
    }
}

@MainActor
enum TextActionRunner {
    static func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    static func lookUpDefinition(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let range = CFRange(location: 0, length: (trimmed as NSString).length)
        if let result = DCSCopyTextDefinition(nil, trimmed as CFString, range) {
            return result.takeRetainedValue() as String
        }
        return nil
    }

    static func openInDictionary(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "dict://\(encoded)") else { return }
        NSWorkspace.shared.open(url)
    }

    static func detectLanguage(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }

    static func findInFrontmostApp(_ text: String) {
        let findPasteboard = NSPasteboard(name: .find)
        findPasteboard.clearContents()
        findPasteboard.setString(text, forType: .string)

        // Send Cmd+F to open the Find bar in the previously active app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            sendKeyCombo(keyCode: 3, flags: .maskCommand) // 'f'
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                // Also paste into the find field in case the app doesn't read NSPasteboard.find automatically
                let pb = NSPasteboard.general
                let previous = pb.string(forType: .string)
                pb.clearContents()
                pb.setString(text, forType: .string)
                sendKeyCombo(keyCode: 9, flags: .maskCommand) // 'v'
                if let previous {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        pb.clearContents()
                        pb.setString(previous, forType: .string)
                    }
                }
            }
        }
    }

    static func searchWeb(_ text: String, engine: SearchEngine) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = engine.searchURL(for: trimmed) else { return }
        NSWorkspace.shared.open(url)
    }

    static func copyLinkWithHighlight(_ text: String, frontmostBundleID: String?) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if let browserURL = activeBrowserURL(bundleID: frontmostBundleID),
           let encodedFragment = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let base = browserURL.components(separatedBy: "#:~:text=").first ?? browserURL
            let separator = base.contains("#") ? "" : "#"
            let highlightURL = "\(base)\(separator):~:text=\(encodedFragment)"
            copy(highlightURL)
            return true
        } else {
            copy("\"\(trimmed)\"")
            return false
        }
    }

    static func share(_ text: String, from view: NSView) {
        let picker = NSSharingServicePicker(items: [text])
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .maxY)
    }

    static func newQuickNote(_ text: String) {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "<br>")

        let scriptSource = """
        tell application "Notes"
            activate
            make new note at folder "Notes" with properties {body:"\(escaped)"}
        end tell
        """
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if error == nil { return }
        }
        // Fallback: copy text and open Notes
        copy(text)
        if let notesURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Notes") {
            NSWorkspace.shared.openApplication(at: notesURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    static func askSiri(_ text: String) {
        copy(text)
        let siriURL = URL(fileURLWithPath: "/System/Applications/Siri.app")
        NSWorkspace.shared.openApplication(at: siriURL, configuration: NSWorkspace.OpenConfiguration())
    }

    private static func activeBrowserURL(bundleID: String?) -> String? {
        guard let bundleID else { return nil }
        let scriptSource: String?
        switch bundleID {
        case "com.apple.Safari", "com.apple.SafariTechnologyPreview":
            scriptSource = "tell application id \"\(bundleID)\" to get URL of front document"
        case "com.google.Chrome", "com.brave.Browser", "com.microsoft.edgemac", "company.thebrowser.Browser", "com.vivaldi.Vivaldi":
            scriptSource = "tell application id \"\(bundleID)\" to get URL of active tab of front window"
        default:
            scriptSource = nil
        }

        guard let source = scriptSource, let script = NSAppleScript(source: source) else {
            return nil
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        return result.stringValue
    }

    private static func sendKeyCombo(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
