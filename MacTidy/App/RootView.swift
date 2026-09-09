import SwiftUI

struct RootView: View {
    @State private var selectedItem: NavigationItem = .dashboard
    let cleanupViewModel: CleanupViewModel
    let journal: TransactionJournal
    let appSettings: AppSettings
    @Bindable var permissionsManager: PermissionsManager
    @Bindable var updatePrompt: UpdatePromptController
    @Binding var availableUpdate: AvailableUpdate?

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "version_unknown".localized
    }

    var body: some View {
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

            VStack(spacing: 0) {
                topNavigationBar
                
                contentView(for: selectedItem)
                    .navigationTitle("MacTidy")
                    .navigationSubtitle(selectedItem.localizedSubtitle ?? "")
                    .toolbar {
                        ToolbarItem(placement: .automatic) {
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // Recreate screen content so every `.localized` string / glass layer
                    // matches the selected language (prevents stale RU labels in EN/FR/…).
                    .id(appSettings.language)
            }
            
            GlassOverlayView(manager: GlassOverlayManager.shared)
        }
        .frame(minWidth: 1024, minHeight: 680)
        .environment(\.locale, appSettings.language.locale)
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
            permissionsManager.showGuidanceIfNeeded()
            presentUpdateIfReady()
        }
        .onChange(of: availableUpdate) { _, _ in
            presentUpdateIfReady()
        }
        .onChange(of: permissionsManager.showGuidance) { _, showing in
            if !showing {
                presentUpdateIfReady()
            }
        }
    }

    private func presentUpdateIfReady() {
        updatePrompt.presentIfNeeded(
            update: availableUpdate,
            fdaShowing: permissionsManager.showGuidance
        )
    }

    // MARK: - Navigation Groups
    private let navGroups: [[NavigationItem]] = [
        [.dashboard],
        [.cleanup, .diskSpace, .duplicates, .uninstaller],
        [.monitor, .processes, .startupServices],
        [.settings]
    ]

    private var topNavigationBar: some View {
        HStack(spacing: 0) {
            brandLockup

            Divider()
                .frame(height: 20)
                .opacity(0.35)
                .padding(.horizontal, 10)

            ForEach(navGroups.indices, id: \.self) { groupIndex in
                let group = navGroups[groupIndex]

                HStack(spacing: 2) {
                    ForEach(group, id: \.self) { item in
                        navButton(for: item)
                    }
                }

                if groupIndex < navGroups.count - 1 {
                    Divider()
                        .frame(height: 18)
                        .opacity(0.4)
                        .padding(.horizontal, 4)
                }
            }

            Spacer(minLength: 10)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .glassEffect(Glass.regular, in: RoundedRectangle(cornerRadius: 12))
        .id(appSettings.language)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    private var brandLockup: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.12), in: Circle())

            Text("MacTidy")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("MacTidy")
    }

    @ViewBuilder
    private func navButton(for item: NavigationItem) -> some View {
        let isSelected = selectedItem == item
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                selectedItem = item
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 22, height: 22)
                // Compact on all locales: label only for the selected item.
                if isSelected {
                    Text(item.localizedTitle)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, isSelected ? 10 : 9)
            .padding(.vertical, 6)
            .frame(minWidth: isSelected ? nil : 40, minHeight: 32)
            .contentShape(Rectangle())
            .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.6))
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor)
                        .glassEffect(Glass.regular.tint(Color.accentColor).interactive(), in: Capsule())
                }
            }
        }
        .buttonStyle(.plain)
        .help(item.localizedTitle)
    }


    @ViewBuilder
    private func contentView(for item: NavigationItem) -> some View {
        switch item {
        case .dashboard:
            DashboardView(journal: journal)
        case .cleanup:
            CleanupView(viewModel: cleanupViewModel)
        case .diskSpace:
            DiskAnalyzerView(settings: appSettings)
        case .duplicates:
            DuplicatesView()
        case .processes:
            ProcessesView(settings: appSettings)
        case .monitor:
            MonitorView()
        case .startupServices:
            StartupServicesView(settings: appSettings)
        case .uninstaller:
            UninstallerView(settings: appSettings, navigateToCleanup: { selectedItem = .cleanup })
        case .settings:
            SettingsView(
                settings: appSettings,
                permissionsManager: permissionsManager,
                onForget: {
                    Task {
                        try? await journal.clear()
                    }
                },
                availableUpdate: $availableUpdate
            )
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
        permissionsManager: PermissionsManager(),
        updatePrompt: UpdatePromptController(),
        availableUpdate: .constant(nil)
    )
}
