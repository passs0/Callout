import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var monitor: SelectionMonitor
    @AppStorage("autoShowEnabled") private var autoShowEnabled: Bool = true
    @AppStorage("translateTargetLang") private var translateTargetLang: String = "en"
    @State private var openAtLogin: Bool = (SMAppService.mainApp.status == .enabled)

    private let languages: [(code: String, name: String)] = [
        ("en", "English"),
        ("zh-Hant", "Chinese (Traditional)"),
        ("zh-Hans", "Chinese (Simplified)"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German")
    ]

    var body: some View {
        Form {
            Section("Permissions") {
                HStack {
                    Image(systemName: monitor.isAccessibilityGranted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(monitor.isAccessibilityGranted ? .green : .orange)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility Access")
                            .font(.headline)
                        Text(monitor.isAccessibilityGranted
                             ? "Granted — text selection works across apps."
                             : "Required to read selected text automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !monitor.isAccessibilityGranted {
                        Button("Grant Access") {
                            monitor.requestAccessibilityPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Refresh") {
                            monitor.refreshAccessibilityStatus()
                        }
                    }
                }
            }

            Section("Behavior") {
                Toggle("Show automatically when selecting text", isOn: $autoShowEnabled)
                    .onChange(of: autoShowEnabled) { _, newValue in
                        monitor.setEnabled(newValue)
                    }

                Toggle("Open at login", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            openAtLogin = (SMAppService.mainApp.status == .enabled)
                        }
                    }

                Picker("Translate To", selection: $translateTargetLang) {
                    ForEach(languages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
            }

            Section("Shortcuts") {
                LabeledContent("Show Selection") {
                    Text("⌥ Space, ⌘⇧E")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 300)
        .onAppear {
            monitor.refreshAccessibilityStatus()
        }
    }
}
