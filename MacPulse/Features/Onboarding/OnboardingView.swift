import SwiftUI
import AppKit

@Observable
final class OnboardingController {
    var isPresented = false

    static let completedKey = "com.macpulse.onboardingCompleted"

    var isCompleted: Bool {
        UserDefaults.standard.bool(forKey: Self.completedKey)
    }

    init() {
        // Eager so first frame already defers heavy dashboard scan under the sheet.
        if !isCompleted {
            isPresented = true
        }
    }

    @discardableResult
    func presentIfNeeded() -> Bool {
        guard !isCompleted else { return false }
        isPresented = true
        return true
    }

    func complete() {
        UserDefaults.standard.set(true, forKey: Self.completedKey)
        isPresented = false
    }

    func replay() {
        UserDefaults.standard.set(false, forKey: Self.completedKey)
        isPresented = true
    }
}

private struct OnboardingActiveKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var onboardingActive: Bool {
        get { self[OnboardingActiveKey.self] }
        set { self[OnboardingActiveKey.self] = newValue }
    }
}

private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case thisMac
    case permissions
    case ready
}

struct OnboardingView: View {
    @Bindable var permissionsManager: PermissionsManager
    @Bindable var onboarding: OnboardingController
    var onStartFirstScan: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme

    @State private var step: OnboardingStep = .welcome

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 0) {
                headerSection
                stepContent
                    .padding(20)
                footerBar
            }
            .frame(width: 520)
            .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            permissionsManager.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissionsManager.refresh()
            if permissionsManager.hasFullDiskAccess, step == .permissions {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { step = .ready }
            }
        }
        .task(id: step) {
            guard step == .permissions else { return }
            while !Task.isCancelled && !permissionsManager.hasFullDiskAccess {
                try? await Task.sleep(for: .milliseconds(1000))
                await MainActor.run {
                    permissionsManager.refresh()
                    if permissionsManager.hasFullDiskAccess {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            step = .ready
                        }
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: headerIcon)
                .font(.system(size: 36))
                .foregroundColor(.white)
                .contentTransition(.symbolEffect(.replace))

            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(headerSubtitle)
                    .font(.subheadline)
                    .opacity(0.85)
            }

            Spacer(minLength: 0)

            stepDots
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background {
            LinearGradient(
                colors: [
                    .accentColor.opacity(colorScheme == .dark ? 0.85 : 0.7),
                    .accentColor.opacity(colorScheme == .dark ? 0.35 : 0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { s in
                Circle()
                    .fill(.white.opacity(s == step ? 1 : 0.35))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.top, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: "onboarding_step_a11y".localized, Int64(step.rawValue + 1), Int64(OnboardingStep.allCases.count)))
    }

    private var headerIcon: String {
        switch step {
        case .welcome: return "sparkles"
        case .thisMac: return "laptopcomputer"
        case .permissions: return "lock.shield"
        case .ready: return "checkmark.circle.fill"
        }
    }

    private var headerTitle: String {
        switch step {
        case .welcome: return "onboarding_welcome_title".localized
        case .thisMac: return "onboarding_thismac_title".localized
        case .permissions: return "onboarding_permissions_title".localized
        case .ready: return "onboarding_ready_title".localized
        }
    }

    private var headerSubtitle: String {
        switch step {
        case .welcome: return "onboarding_welcome_sub".localized
        case .thisMac: return "onboarding_thismac_sub".localized
        case .permissions: return "onboarding_permissions_sub".localized
        case .ready: return "onboarding_ready_sub".localized
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            featureGrid
        case .thisMac:
            thisMacCard
        case .permissions:
            permissionsCard
        case .ready:
            readyCard
        }
    }

    private var featureGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "sparkles", tint: .teal, title: "onboarding_feat_clean".localized, detail: "onboarding_feat_clean_sub".localized)
            featureRow(icon: "trash", tint: .red, title: "onboarding_feat_uninstall".localized, detail: "onboarding_feat_uninstall_sub".localized)
            featureRow(icon: "folder.fill", tint: .orange, title: "onboarding_feat_disk".localized, detail: "onboarding_feat_disk_sub".localized)
            featureRow(icon: "waveform.path.ecg", tint: .green, title: "onboarding_feat_monitor".localized, detail: "onboarding_feat_monitor_sub".localized)
        }
    }

    private func featureRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .glassCard(cornerRadius: 12)
    }

    private var thisMacCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "laptopcomputer")
                    .font(.title2)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("menu_dashboard".localized)
                        .font(.headline)
                    Text("onboarding_thismac_body".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .glassCard(cornerRadius: 12)

            VStack(alignment: .leading, spacing: 10) {
                thisMacBullet(icon: "chart.pie.fill", text: "onboarding_thismac_bullet_disk".localized)
                thisMacBullet(icon: "info.circle.fill", text: "onboarding_thismac_bullet_system".localized)
                thisMacBullet(icon: "clock.fill", text: "onboarding_thismac_bullet_recent".localized)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 12)
        }
    }

    private func thisMacBullet(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .frame(width: 16)
            Text(text)
                .font(.callout)
        }
    }

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if permissionsManager.hasFullDiskAccess {
                HStack(spacing: 14) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("permissions_status_active_banner".localized)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("onboarding_ready_fda_ok".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .glassCard(cornerRadius: 12)
            } else {
                // Scan depth comparison
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("permissions_scan_depth_standard".localized, systemImage: "bolt")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("permissions_scan_depth_standard_sub".localized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label("permissions_scan_depth_deep".localized, systemImage: "sparkles")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                            Spacer(minLength: 0)
                            Text("Recommended")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.18), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                        }
                        Text("permissions_scan_depth_deep_sub".localized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.25), lineWidth: 1))
                }

                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    instructionStep(1, "permissions_step1".localized)
                    instructionStep(2, "permissions_step2".localized)
                    instructionStep(3, "permissions_step3".localized)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 10)

                // Action buttons
                HStack(spacing: 10) {
                    Button {
                        permissionsManager.openFullDiskAccessSettings()
                    } label: {
                        Label("permissions_open_settings".localized, systemImage: "gear")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                    }
                    .glassButtonStyle()
                    .controlSize(.large)

                    Button {
                        permissionsManager.revealAppInFinder()
                    } label: {
                        Label("permissions_show_in_finder".localized, systemImage: "folder.badge.gearshape")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                    }
                    .glassButtonStyle()
                    .controlSize(.large)
                    .help("permissions_finder_tip".localized)

                    Button {
                        permissionsManager.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                            .frame(width: 28, height: 28)
                    }
                    .glassButtonStyle()
                    .controlSize(.large)
                    .help("permissions_check_status".localized)
                }

                // Privacy guarantee note
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("permissions_privacy_note".localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func instructionStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 18, height: 18)
                .background(Color.accentColor.opacity(0.15), in: Circle())
            Text(text)
                .font(.callout)
        }
    }

    private var readyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: permissionsManager.hasFullDiskAccess ? "checkmark.seal.fill" : "sparkles")
                    .font(.title2)
                    .foregroundStyle(permissionsManager.hasFullDiskAccess ? .green : Color.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(permissionsManager.hasFullDiskAccess
                          ? "onboarding_ready_fda_ok".localized
                          : "onboarding_ready_fda_skip".localized)
                        .font(.headline)
                    Text("onboarding_ready_body".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .glassCard(cornerRadius: 12)

            HStack(spacing: 12) {
                Image(systemName: "bolt.badge.checkmark.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                Text(permissionsManager.hasFullDiskAccess ? "permissions_scan_depth_deep_sub".localized : "permissions_scan_depth_standard_sub".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 10)
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            if step != .welcome {
                Button(step == .ready ? "onboarding_explore_dashboard".localized : "onboarding_back".localized) {
                    if step == .ready {
                        finish(startScan: false)
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            step = OnboardingStep(rawValue: step.rawValue - 1) ?? .welcome
                        }
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Button("onboarding_skip".localized) {
                    finish(startScan: false)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                advance()
            } label: {
                if step == .ready {
                    Label("onboarding_start_first_scan".localized, systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 140)
                        .frame(height: 28)
                } else {
                    Text(primaryButtonTitle)
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 120)
                        .frame(height: 28)
                }
            }
            .glassButtonStyle()
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var primaryButtonTitle: String {
        switch step {
        case .welcome, .thisMac: return "onboarding_continue".localized
        case .permissions:
            return permissionsManager.hasFullDiskAccess
                ? "onboarding_continue".localized
                : "onboarding_continue_without".localized
        case .ready: return "onboarding_start_first_scan".localized
        }
    }

    private func advance() {
        if step == .ready {
            finish(startScan: true)
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            step = OnboardingStep(rawValue: step.rawValue + 1) ?? .ready
        }
    }

    private func finish(startScan: Bool = false) {
        onboarding.complete()
        if startScan {
            onStartFirstScan?()
        }
    }
}

#Preview {
    let manager = PermissionsManager()
    let onboarding = OnboardingController()
    onboarding.isPresented = true
    return OnboardingView(permissionsManager: manager, onboarding: onboarding)
}
