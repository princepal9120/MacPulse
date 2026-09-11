import SwiftUI

struct RootView: View {
    @State private var selection: SidebarDestination = .feature(.dashboard)
    let cleanupViewModel: CleanupViewModel
    let journal: TransactionJournal
    let appSettings: AppSettings
    let monitorViewModel: MonitorViewModel
    let privacyMonitorViewModel: PrivacyMonitorViewModel
    @Bindable var permissionsManager: PermissionsManager
    @Bindable var updatePrompt: UpdatePromptController
    @Binding var availableUpdate: AvailableUpdate?
    @State private var onboarding = OnboardingController()

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "version_unknown".localized
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .overlay {
            GlassOverlayView(manager: GlassOverlayManager.shared)
        }
        .frame(minWidth: 1080, minHeight: 700)
        .environment(\.locale, appSettings.language.locale)
        .sheet(isPresented: $onboarding.isPresented) {
            OnboardingView(permissionsManager: permissionsManager, onboarding: onboarding)
        }
        .sheet(isPresented: $permissionsManager.showGuidance) {
            PermissionsView(permissionsManager: permissionsManager)
        }
        .sheet(isPresented: $updatePrompt.showSheet) {
            if let update = availableUpdate {
                UpdateAvailableView(
                    update: update,
                    currentVersion: currentVersion,
                    onDismissLater: { updatePrompt.dismissTemporarily() },
                    onDismissForVersion: { updatePrompt.dismissForVersion(update.version) }
                )
            }
        }
        .onAppear {
            appSettings.applyTheme()
        }
        .task {
            permissionsManager.refresh()
            // First launch: full onboarding (includes FDA). Later: FDA sheet only if still missing.
            if !onboarding.presentIfNeeded() {
                permissionsManager.showGuidanceIfNeeded()
            }
            presentUpdateIfReady()
        }
        .onChange(of: availableUpdate) { _, _ in
            presentUpdateIfReady()
        }
        .onChange(of: onboarding.isPresented) { _, showing in
            if !showing {
                presentUpdateIfReady()
            }
        }
        .onChange(of: permissionsManager.showGuidance) { _, showing in
            if !showing {
                presentUpdateIfReady()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .macPulseNavigate)) { notification in
            guard let rawValue = notification.object as? String,
                  let item = NavigationItem(rawValue: rawValue) else { return }
            selection = .feature(item)
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .macPulseReplayOnboarding)) { _ in
            permissionsManager.showGuidance = false
            onboarding.replay()
        }
    }

    private func presentUpdateIfReady() {
        updatePrompt.presentIfNeeded(
            update: availableUpdate,
            fdaShowing: permissionsManager.showGuidance || onboarding.isPresented
        )
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            ForEach(SidebarSection.all) { section in
                if let titleKey = section.titleKey {
                    Section(titleKey.localized) { rows(for: section) }
                } else {
                    Section { rows(for: section) }
                }
            }
        }
        .listStyle(.sidebar)
        .padding(.leading, 8)
        // Keep labels readable when macOS restores a narrow previous window.
        .navigationSplitViewColumnWidth(min: 240, ideal: 252, max: 300)
        .safeAreaInset(edge: .top, spacing: 0) { brandLockup }
        // Rebuild so every `.localized` row matches the selected language.
        .id(appSettings.language)
    }

    private func rows(for section: SidebarSection) -> some View {
        ForEach(section.items) { destination in
            Label {
                Text(destination.localizedTitle)
                    .lineLimit(1)
            } icon: {
                Image(systemName: destination.systemImage)
                    .foregroundStyle(destination.tint)
            }
            .padding(.leading, 18)
            .tag(destination)
        }
    }

    private var brandLockup: some View {
        HStack(spacing: 9) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12), in: Circle())

            Text("MacPulse")
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 30)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("MacPulse")
    }

    // MARK: - Detail

    private var detail: some View {
        ZStack {
            // A quiet, platform-native canvas keeps every screen visually related
            // without competing with the data-heavy cards and lists.
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.09),
                    Color.clear,
                    Color.primary.opacity(0.025)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Recreate screen content so every `.localized` string / glass layer
                // matches the selected language (prevents stale RU labels in EN/FR/…).
                .id(appSettings.language)
        }
        .navigationTitle(selection.localizedTitle)
        .navigationSubtitle(selection.localizedSubtitle ?? "")
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .feature(let item):
            featureView(for: item)
        case .setting(let category):
            SettingsDetailView(
                category: category,
                settings: appSettings,
                permissionsManager: permissionsManager,
                availableUpdate: $availableUpdate,
                onForget: {
                    Task {
                        try? await journal.clear()
                    }
                },
                onSelectCategory: { selection = .setting($0) }
            )
        }
    }

    @ViewBuilder
    private func featureView(for item: NavigationItem) -> some View {
        switch item {
        case .dashboard:
            DashboardView(
                journal: journal,
                monitorViewModel: monitorViewModel,
                privacyMonitor: privacyMonitorViewModel
            )
        case .cleanup:
            CleanupView(viewModel: cleanupViewModel)
        case .diskSpace:
            DiskAnalyzerView(settings: appSettings)
        case .duplicates:
            DuplicatesView()
        case .processes:
            ProcessesView(settings: appSettings)
        case .monitor:
            MonitorView(viewModel: monitorViewModel)
        case .privacy:
            PrivacyAlertsView(viewModel: privacyMonitorViewModel)
        case .startupServices:
            StartupServicesView(settings: appSettings)
        case .uninstaller:
            UninstallerView(settings: appSettings, navigateToCleanup: { selection = .feature(.cleanup) })
        }
    }
}

#Preview {
    let journal = TransactionJournal()
    let settings = AppSettings()
    let commandRunner = CommandRunner()
    RootView(
        cleanupViewModel: CleanupViewModel(
            engine: CleanupEngine(commandRunner: commandRunner),
            journal: journal,
            settings: settings
        ),
        journal: journal,
        appSettings: settings,
        monitorViewModel: MonitorViewModel(),
        privacyMonitorViewModel: PrivacyMonitorViewModel(),
        permissionsManager: PermissionsManager(),
        updatePrompt: UpdatePromptController(),
        availableUpdate: .constant(nil)
    )
}
