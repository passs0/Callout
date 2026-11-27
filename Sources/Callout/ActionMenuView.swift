import AppKit
import SwiftUI
import Translation

enum PopoverDisplayMode: Equatable {
    case compactPill
    case lookUpResult(definition: String?)
    case translateResult(translated: String?, sourceLang: String?, isLoading: Bool)
}

@MainActor
final class PopoverState: ObservableObject {
    @Published var selectedText: String = ""
    @Published var frontmostBundleID: String?
    @Published var mode: PopoverDisplayMode = .compactPill

    var onRequestResize: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onShowNativeMenu: (() -> Void)?

    func reset(text: String, bundleID: String?) {
        selectedText = text
        frontmostBundleID = bundleID
        mode = .compactPill
    }
}

struct ActionMenuView: View {
    @ObservedObject var state: PopoverState
    @AppStorage("translateTargetLang") private var translateTargetLang: String = "en"
    @Namespace private var glassNamespace
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var showSystemTranslate: Bool = false

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            Group {
                switch state.mode {
                case .compactPill:
                    compactPillView
                case .lookUpResult(let definition):
                    lookUpResultView(definition: definition)
                case .translateResult(let translated, let sourceLang, let isLoading):
                    translateResultView(translated: translated, sourceLang: sourceLang, isLoading: isLoading)
                }
            }
        }
        .padding(32)
        .fixedSize()
        .environment(\.controlActiveState, .active)
        .translationTask(translationConfig) { @Sendable session in
            let text = await MainActor.run { state.selectedText }
            do {
                let response = try await session.translate(text)
                let targetText = response.targetText
                let sourceLang = response.sourceLanguage.minimalIdentifier
                await MainActor.run {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
                        state.mode = .translateResult(
                            translated: targetText,
                            sourceLang: sourceLang,
                            isLoading: false
                        )
                    }
                    state.onRequestResize?()
                }
            } catch {
                await MainActor.run {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
                        state.mode = .translateResult(
                            translated: nil,
                            sourceLang: nil,
                            isLoading: false
                        )
                    }
                    state.onRequestResize?()
                }
            }
        }
        .translationPresentation(isPresented: $showSystemTranslate, text: state.selectedText)
    }

    // MARK: - Compact Horizontal Pill

    private var compactPillView: some View {
        HStack(spacing: 2) {
            pillButton("Copy") {
                TextActionRunner.copy(state.selectedText)
                state.onDismiss?()
            }

            pillButton("Look Up") {
                openLookUp()
            }

            pillButton("Translate") {
                openTranslate()
            }

            pillButton("Find") {
                let text = state.selectedText
                state.onDismiss?()
                TextActionRunner.findInFrontmostApp(text)
            }

            Divider()
                .frame(height: 18)
                .padding(.horizontal, 2)

            Button {
                state.onShowNativeMenu?()
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 26, height: 26)
                    .contentShape(Circle())
            }
            .buttonStyle(HoverHighlightButtonStyle(shape: AnyShape(Circle())))
            .help("More Actions")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.clear, in: .capsule)
        .glassEffectID("menuSurface", in: glassNamespace)
        .onSecondaryClick {
            state.onShowNativeMenu?()
        }
    }

    private func pillButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Text(title)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .contentShape(Capsule())
        }
        .buttonStyle(HoverHighlightButtonStyle(shape: AnyShape(Capsule())))
    }

    // MARK: - Inline Look Up Card

    private func lookUpResultView(definition: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        state.mode = .compactPill
                    }
                    state.onRequestResize?()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderless)

                Text("Look Up")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button("Dictionary") {
                    TextActionRunner.openInDictionary(state.selectedText)
                    state.onDismiss?()
                }
                .font(.system(size: 11.5, weight: .medium))
                .buttonStyle(.borderless)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text(state.selectedText.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 15, weight: .semibold))

                    if let definition, !definition.isEmpty {
                        Text(definition)
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    } else {
                        Text("No local dictionary entry found.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 180)
        }
        .padding(14)
        .frame(width: 300)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .glassEffectID("menuSurface", in: glassNamespace)
    }

    // MARK: - Inline Translate Card

    private func translateResultView(translated: String?, sourceLang: String?, isLoading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        state.mode = .compactPill
                    }
                    state.onRequestResize?()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderless)

                Text("Translate")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Menu {
                    ForEach(translateLanguages, id: \.code) { lang in
                        Button {
                            translateTargetLang = lang.code
                            openTranslate()
                        } label: {
                            if translateTargetLang == lang.code {
                                Label(lang.name, systemImage: "checkmark")
                            } else {
                                Text(lang.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(translateLanguageName(for: translateTargetLang))
                            .font(.system(size: 11.5, weight: .medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                if let translated {
                    Button {
                        TextActionRunner.copy(translated)
                        state.onDismiss?()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                    .help("Copy Translation")
                }

                Button("System") {
                    showSystemTranslate = true
                }
                .font(.system(size: 11.5, weight: .medium))
                .buttonStyle(.borderless)
                .help("Open Apple System Translate")
            }

            Divider()

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Translating...")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if let translated {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        if let sourceLang {
                            Text("Detected: \(Locale.current.localizedString(forLanguageCode: sourceLang) ?? sourceLang)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Text(translated)
                            .font(.system(size: 13.5, weight: .medium))
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
            } else {
                Text("Tap System Translate above to download or translate this language pair.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 300)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .glassEffectID("menuSurface", in: glassNamespace)
    }

    // MARK: - Helpers

    private func openLookUp() {
        let definition = TextActionRunner.lookUpDefinition(for: state.selectedText)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
            state.mode = .lookUpResult(definition: definition)
        }
        state.onRequestResize?()
    }

    private let translateLanguages: [(code: String, name: String)] = [
        ("en", "English"),
        ("zh-Hant", "Chinese (Trad.)"),
        ("zh-Hans", "Chinese (Simp.)"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German")
    ]

    private func translateLanguageName(for code: String) -> String {
        translateLanguages.first(where: { $0.code == code })?.name ?? code
    }

    private func openTranslate() {
        let target = translateTargetLang
        let targetLanguage = Locale.Language(identifier: target)
        let detectedCode = detectSourceLanguageCode(for: state.selectedText)

        if let detectedCode, detectedCode.hasPrefix(target) || target.hasPrefix(detectedCode) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
                state.mode = .translateResult(
                    translated: "Text is already in \(translateLanguageName(for: target)). Choose a different target language above.",
                    sourceLang: detectedCode,
                    isLoading: false
                )
            }
            state.onRequestResize?()
            return
        }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
            state.mode = .translateResult(translated: nil, sourceLang: nil, isLoading: true)
        }
        state.onRequestResize?()

        let sourceLanguage = detectedCode.map { Locale.Language(identifier: $0) }
        if translationConfig?.target == targetLanguage && translationConfig?.source == sourceLanguage {
            translationConfig?.invalidate()
        } else {
            translationConfig = TranslationSession.Configuration(source: sourceLanguage, target: targetLanguage)
        }
    }

    private func detectSourceLanguageCode(for text: String) -> String? {
        if let detected = TextActionRunner.detectLanguage(of: text) {
            return detected
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed.allSatisfy({ $0.isASCII }) {
            return "en"
        }
        return nil
    }
}

struct HoverHighlightButtonStyle: ButtonStyle {
    var shape: AnyShape
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let active = isHovered || configuration.isPressed
        configuration.label
            .foregroundStyle(active ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .background {
                if configuration.isPressed {
                    shape.fill(Color.accentColor.opacity(0.85))
                } else if isHovered {
                    shape.fill(Color.accentColor)
                }
            }
            .overlay {
                AlwaysActiveTrackingView { hovering in
                    isHovered = hovering
                }
            }
    }
}

private struct AlwaysActiveTrackingView: NSViewRepresentable {
    var onHoverChange: (Bool) -> Void

    func makeNSView(context: Context) -> TrackingNSView {
        let view = TrackingNSView()
        view.onHoverChange = onHoverChange
        return view
    }

    func updateNSView(_ nsView: TrackingNSView, context: Context) {
        nsView.onHoverChange = onHoverChange
    }

    final class TrackingNSView: NSView {
        var onHoverChange: ((Bool) -> Void)?
        private var trackingArea: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let existing = trackingArea {
                removeTrackingArea(existing)
            }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            trackingArea = area
        }

        override func mouseEntered(with event: NSEvent) {
            onHoverChange?(true)
        }

        override func mouseExited(with event: NSEvent) {
            onHoverChange?(false)
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}

private struct SecondaryClickOverlay: NSViewRepresentable {
    var action: () -> Void

    func makeNSView(context: Context) -> SecondaryClickNSView {
        let view = SecondaryClickNSView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: SecondaryClickNSView, context: Context) {
        nsView.action = action
    }

    final class SecondaryClickNSView: NSView {
        var action: (() -> Void)?

        override func rightMouseUp(with event: NSEvent) {
            action?()
        }
    }
}

extension View {
    func onSecondaryClick(perform action: @escaping () -> Void) -> some View {
        background(SecondaryClickOverlay(action: action))
    }
}
