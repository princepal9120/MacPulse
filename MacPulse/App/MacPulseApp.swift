import SwiftUI
import OSLog


private let crashLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "input.MacPulse", category: "Crash")

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // stay resident in menu bar (Monitor keeps running)
    }
}

@main
struct MacPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // Note: AppIntents/linkd errors (com.apple.linkd.autoShortcut connection failures)
    // are expected system noise on some macOS versions. They cannot be fixed in app code
    // as they originate from the system's AppIntents framework initialization.
    @Environment(\.openWindow) private var openWindow
    
    private let commandRunner = CommandRunner()
    private let journal = TransactionJournal()
    private let cleanupViewModel: CleanupViewModel
    private let appSettings = AppSettings()
    private let monitorViewModel = MonitorViewModel()
    private let privacyMonitorViewModel = PrivacyMonitorViewModel()
    private let permissionsManager = PermissionsManager()
    private let updateChecker = UpdateChecker()
    private let updatePrompt = UpdatePromptController()
    @State private var availableUpdate: AvailableUpdate? = nil
    @State private var isCheckingForUpdates = false
    
    // ponytail: detect test runner so app host stays inert during unit tests
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil
    }

    init() {
        Self.installCrashHandlers()

        let engine = CleanupEngine(commandRunner: commandRunner)
        self.cleanupViewModel = CleanupViewModel(engine: engine, journal: journal, settings: appSettings)

        guard !Self.isRunningTests else { return }

        // Preload Launch Services cache and register AppShortcuts
        Task {
            await LSRegisterCache().warmup()
            MacPulseShortcuts.updateAppShortcutParameters()
        }
    }
    
    private static func installCrashHandlers() {
        NSSetUncaughtExceptionHandler { exception in
            let desc = exception.description
            crashLogger.fault("Uncaught exception: \(exception.name.rawValue): \(desc)")
            crashLogger.fault("Stack trace: \(exception.callStackSymbols.joined(separator: "\n"))")
            fflush(stderr)
            abort()
        }
        
        signal(SIGABRT) { _ in
            crashLogger.fault("Received SIGABRT")
            fflush(stderr)
            _exit(1)
        }
        signal(SIGSEGV) { _ in
            crashLogger.fault("Received SIGSEGV")
            fflush(stderr)
            _exit(1)
        }
        signal(SIGBUS) { _ in
            crashLogger.fault("Received SIGBUS")
            fflush(stderr)
            _exit(1)
        }
    }

    var body: some Scene {
        WindowGroup("MacPulse") {
            if Self.isRunningTests {
                EmptyView()
            } else {
                RootView(
                    cleanupViewModel: cleanupViewModel,
                    journal: journal,
                    appSettings: appSettings,
                    monitorViewModel: monitorViewModel,
                    privacyMonitorViewModel: privacyMonitorViewModel,
                    permissionsManager: permissionsManager,
                    updatePrompt: updatePrompt,
                    availableUpdate: $availableUpdate
                )
                .task {
                    availableUpdate = await updateChecker.checkForUpdate()
                    monitorViewModel.start()
                    privacyMonitorViewModel.start()
                }
            }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1200, height: 760)
        .defaultPosition(.center)

        MenuBarExtra("MacPulse", systemImage: "waveform.path.ecg") {
            MonitorHUDView(viewModel: monitorViewModel, privacyMonitor: privacyMonitorViewModel)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("about_title".localized) {
                    openWindow(id: "about")
                }
                Button(isCheckingForUpdates ? "update.checking".localized : "update.check".localized) {
                    isCheckingForUpdates = true
                    Task { @MainActor in
                        let result = await updateChecker.checkForUpdate()
                        availableUpdate = result
                        isCheckingForUpdates = false
                        
                        let alert = NSAlert()
                        alert.messageText = "update.check".localized
                        if let result {
                            alert.informativeText = String(format: "update.available".localized, result.version)
                            let downloadTitle = result.dmgURL != nil
                                ? "update.download_dmg".localized
                                : "update.download".localized
                            alert.addButton(withTitle: downloadTitle)
                            alert.addButton(withTitle: "cancel".localized)
                            let response = alert.runModal()
                            if response == .alertFirstButtonReturn {
                                UpdatePromptController.open(result)
                            }
                        } else {
                            let accessory = NSHostingView(rootView: UpToDateAlertView())
                            accessory.frame = NSRect(x: 0, y: 0, width: 300, height: 70)
                            alert.accessoryView = accessory
                            alert.addButton(withTitle: "close".localized)
                            alert.runModal()
                        }
                    }
                }
                .disabled(isCheckingForUpdates)
                
                Button("menu_donate".localized) {
                    if let url = URL(string: "https://github.com/princepal9120/MacPulse/blob/main/DONATE.md") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        
        Window("about_title".localized, id: "about") {
            AboutView(availableUpdate: availableUpdate)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        
        Window("permissions_window_title".localized, id: "permissions") {
            PermissionsView(permissionsManager: permissionsManager)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

struct UpToDateAlertView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("update.up_to_date_message".localized)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("update.releases_label".localized)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Link("https://github.com/princepal9120/MacPulse/releases", destination: URL(string: "https://github.com/princepal9120/MacPulse/releases")!)
                        .font(.system(size: 11))
                }
            }
        }
        .frame(width: 300, height: 70, alignment: .leading)
    }
}
