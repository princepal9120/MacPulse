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
    @State private var diskAnalyzerViewModel = DiskAnalyzerViewModel()

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
        .frame(minWidth: 860, minHeight: 580)
        .environment(\.locale, appSettings.language.locale)
        .environment(\.onboardingActive, onboarding.isPresented)
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
                    Section {
                        rows(for: section)
                    } header: {
                        Text(titleKey.localized)
                            .font(.system(size: 11, weight: .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section { rows(for: section) }
                }
            }
        }
        .listStyle(.sidebar)
        .padding(.leading, 8)
        .scrollContentBackground(.hidden)
        // Responsive sidebar column width for compact and full-sized windows.
        .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
        .safeAreaInset(edge: .top, spacing: 0) { brandLockup }
        .safeAreaInset(edge: .bottom, spacing: 0) { sidebarStatusStrip }
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
                    .frame(width: 18, alignment: .center)
            }
            .tag(destination)
            .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 12))
            .listRowBackground(rowBackground(for: destination))
        }
    }

    @ViewBuilder
    private func rowBackground(for destination: SidebarDestination) -> some View {
        if selection == destination {
            // Selected row: soft accent pill instead of the default tint wash.
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(destination.tint.opacity(0.14))
                .padding(.vertical, 1)
        }
    }

    private var sidebarStatusStrip: some View {
        let total = Int64(monitorViewModel.metrics.totalDisk)
        let free = Int64(monitorViewModel.metrics.freeDisk)
        let usedPercent: Double = total > 0 ? Double(total - free) / Double(total) * 100 : 0
        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.10), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: usedPercent / 100)
                    .stroke(
                        AngularGradient(colors: [.teal, .blue], center: .center),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text("\(Int(usedPercent))%")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text("dashboard_disk_usage".localized)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("\(free.formattedByteCount()) free")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                Text("dashboard_healthy".localized)
                    .font(.caption2.weight(.semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.12), in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var brandLockup: some View {
        HStack(spacing: 9) {
            MacPulseLogo(size: 28)

            Text("MacPulse")
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Spacer(minLength: 0)
        }
        // Matches the leading edge used by every sidebar row.
        .padding(.horizontal, 22)
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
            DiskAnalyzerView(settings: appSettings, viewModel: diskAnalyzerViewModel)
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
