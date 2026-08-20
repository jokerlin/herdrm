import AppKit
import Darwin
import HerdrKit
import Sparkle
import SwiftUI
import UserNotifications

/// Holds app termination open long enough to tear the SSH tunnels down: without
/// `.terminateLater` the process dies before the teardown task gets to run, and the
/// `ssh` children survive with PPID 1 along with their sockets.
///
/// The delegate owns the model rather than borrowing it from the window: closing the
/// last window (⌘W) would otherwise drop the only strong reference, and the quit that
/// follows would find nothing left to tear down.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task { @MainActor in
            await model.shutdownAllSessions()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

private struct AppModelFocusedValueKey: FocusedValueKey {
    typealias Value = AppModel
}

extension FocusedValues {
    var appModel: AppModel? {
        get { self[AppModelFocusedValueKey.self] }
        set { self[AppModelFocusedValueKey.self] = newValue }
    }
}

@main
struct HerdrMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("app.theme") private var themePreference = "system"
    @FocusedValue(\.appModel) private var focusedModel

    private let updaterController: SPUStandardUpdaterController

    init() {
        if ProcessInfo.processInfo.environment[SSHCredentialStore.askPassModeEnvironmentKey] == "1" {
            Self.runSSHAskPass()
        }
        SSHCredentialStore.purgeAuthorizations()
        Self.migrateThemeSettings()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: appDelegate.model)
                .onAppear { Self.applyTheme(themePreference) }
                .onChange(of: themePreference) { _, newValue in
                    Self.applyTheme(newValue)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            // herdrm is a single-window console: a second window would duplicate the
            // whole device tree, so New Window gives up ⌘N to the action that matters.
            CommandGroup(replacing: .newItem) {
                Button("New Agent") { focusedModel?.showNewAgent = true }
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(focusedModel == nil)
                Button("New Space") { focusedModel?.showNewSpace = true }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .disabled(focusedModel == nil)
            }

            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updaterController.checkForUpdates(nil)
                }
            }
        }

        Settings {
            SettingsView()
        }
    }

    /// One-shot migration: the light/dark theme pair collapsed into terminal.theme.
    private static func migrateThemeSettings() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: TerminalDefaults.themeKey) == nil,
           let legacy = ["terminal.lightTheme", "terminal.darkTheme"]
               .compactMap({ defaults.string(forKey: $0) })
               .first(where: { !$0.isEmpty }) {
            defaults.set(legacy, forKey: TerminalDefaults.themeKey)
        }
        defaults.removeObject(forKey: "terminal.lightTheme")
        defaults.removeObject(forKey: "terminal.darkTheme")
    }

    static func applyTheme(_ preference: String) {
        switch preference {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }

    private static func runSSHAskPass() -> Never {
        let environment = ProcessInfo.processInfo.environment
        guard let rawID = environment[SSHCredentialStore.authorizationIDEnvironmentKey],
              let authorizationID = UUID(uuidString: rawID),
              let password = try? SSHCredentialStore.consumePassword(authorizationID: authorizationID)
        else {
            Darwin.exit(EXIT_FAILURE)
        }
        FileHandle.standardOutput.write(Data("\(password)\n".utf8))
        Darwin.exit(EXIT_SUCCESS)
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            AppearanceSettingsView()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            TerminalSettingsView()
                .tabItem { Label("Terminal", systemImage: "terminal") }
            NotificationSettingsView()
                .tabItem { Label("Notifications", systemImage: "bell") }
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 420)
    }
}

struct TerminalSettingsView: View {
    @AppStorage(TerminalDefaults.fontNameKey) private var fontName = ""
    @AppStorage(TerminalDefaults.fontSizeKey) private var fontSize = TerminalDefaults.defaultFontSize
    @AppStorage(TerminalDefaults.themeKey) private var theme = ""
    @AppStorage(TerminalDefaults.matchSidebarKey) private var matchSidebar = true
    @AppStorage("terminal.mouseReporting") private var mouseReporting = true

    private let families = TerminalDefaults.monospacedFamilies()
    private let themeNames = TerminalThemeCatalog.availableNames()

    private var previewSpec: TerminalThemeSpec? {
        TerminalThemeCatalog.spec(named: theme)
    }

    var body: some View {
        Form {
            Picker("Font", selection: $fontName) {
                Text("System Mono (SF Mono)").tag("")
                Divider()
                ForEach(families, id: \.self) { family in
                    Text(family).tag(family)
                }
            }

            HStack {
                Slider(value: $fontSize, in: 9...22, step: 0.5) {
                    Text("Size")
                }
                Text(String(format: "%.1f pt", fontSize))
                    .font(.system(size: 11.5).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
                Stepper("", value: $fontSize, in: 9...22, step: 0.5)
                    .labelsHidden()
            }

            Picker("Theme", selection: $theme) {
                Text("Default").tag("")
                Divider()
                ForEach(themeNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }

            Toggle(isOn: $matchSidebar) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Match sidebar to theme")
                    Text("Paints the sidebar with the terminal theme's background instead of the system material.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $mouseReporting) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Mouse reporting")
                    Text("Forwards clicks and drags to TUI apps that ask for them. Turn off to always select text with the mouse — Shift-drag selects either way.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }

            Button("Reset to Defaults") {
                fontName = ""
                fontSize = TerminalDefaults.defaultFontSize
                theme = ""
                matchSidebar = true
                mouseReporting = true
            }

            Section {
                Text("Preview")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("❯ herdr agent attach w1:p1 — 中文 ABC 0123")
                    .font(Font(TerminalDefaults.font(name: fontName, size: fontSize)))
                    .foregroundStyle(previewForeground)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(previewBackground, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(20)
    }

    private var previewBackground: Color {
        previewSpec.map { Color(nsColor: $0.background.nsColor) } ?? Theme.terminalBackground
    }

    private var previewForeground: Color {
        previewSpec.map { Color(nsColor: $0.foreground.nsColor) } ?? Theme.text
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("app.theme") private var themePreference = "system"

    var body: some View {
        Form {
            Picker("Theme", selection: $themePreference) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
            Text("The default terminal colors follow the app theme; a theme picked in the Terminal tab applies in both modes.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}

struct NotificationSettingsView: View {
    @AppStorage("notifications.enabled") private var enabled = true
    @AppStorage("notifications.sound") private var sound = true
    @State private var authorization: UNAuthorizationStatus?

    var body: some View {
        Form {
            Toggle("Notify when an agent finishes or needs input", isOn: $enabled)
            Toggle("Play a sound", isOn: $sound)
            Text("Finished agents only notify while you're not watching them — herdr reports panes you have open as idle, not done.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Divider()

            switch authorization {
            case .denied:
                HStack(spacing: 8) {
                    Text("Notifications are disabled in System Settings.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                    Button("Open System Settings…") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.small)
                }
            case .notDetermined:
                HStack(spacing: 8) {
                    Text("Notification permission hasn't been granted yet.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                    Button("Request Permission") {
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
                            refreshAuthorization()
                        }
                    }
                    .controlSize(.small)
                }
            case .authorized, .provisional:
                Text("Notification permission granted.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            default:
                EmptyView()
            }
        }
        .padding(20)
        .onAppear { refreshAuthorization() }
    }

    private func refreshAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { authorization = settings.authorizationStatus }
        }
    }
}

struct AboutSettingsView: View {
    var body: some View {
        Form {
            Text("herdrm — a native macOS console for herdr.")
                .font(.system(size: 12.5))
            Text("Devices are managed from the switcher in the sidebar footer.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}
