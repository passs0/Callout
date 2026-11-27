import AppKit
import CoreServices
import NaturalLanguage

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

    static func askSiri(_ text: String) {
        copy(text)
        let siriURL = URL(fileURLWithPath: "/System/Applications/Siri.app")
        NSWorkspace.shared.openApplication(at: siriURL, configuration: NSWorkspace.OpenConfiguration())
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
