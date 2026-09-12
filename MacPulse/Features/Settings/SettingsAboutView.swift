import SwiftUI

struct SettingsAboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsPageHeader(category: .about)
                linksCard
                privacySafetyCard
            }
            .padding(24)
        }
    }

    private var linksCard: some View {
        GlassCard(
            header: {
                SettingsSectionHeader("settings_about_resources".localized, subtitle: "settings_about_resources_sub".localized, iconName: "link", iconColor: .cyan)
            },
            content: {
                VStack(spacing: 8) {
                    linkRow("settings_about_github".localized, subtitle: "https://github.com/princepal9120/MacPulse", icon: "curlybraces.square.fill", iconColor: .blue, url: "https://github.com/princepal9120/MacPulse")
                    SettingsDivider()
                    linkRow("settings_about_github_releases".localized, subtitle: "https://github.com/princepal9120/MacPulse/releases", icon: "arrow.down.app.fill", iconColor: .green, url: "https://github.com/princepal9120/MacPulse/releases")
                    SettingsDivider()
                    linkRow("settings_about_wiki".localized, subtitle: "settings_about_wiki_sub".localized, icon: "text.book.closed.fill", iconColor: .purple, url: "https://github.com/princepal9120/MacPulse/wiki")
                    SettingsDivider()
                    linkRow("settings_about_report_issue".localized, subtitle: "https://github.com/princepal9120/MacPulse/issues", icon: "ladybug.fill", iconColor: .orange, url: "https://github.com/princepal9120/MacPulse/issues")
                }
            }
        )
    }

    private func linkRow(_ title: String, subtitle: String, icon: String, iconColor: Color, url: String) -> some View {
        Button {
            if let linkURL = URL(string: url) {
                NSWorkspace.shared.open(linkURL)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(iconColor)
                    .frame(width: 32, height: 32)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.up.forward.app")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var privacySafetyCard: some View {
        GlassCard(
            header: {
                SettingsSectionHeader("settings_privacy_safety_title".localized, subtitle: "settings_privacy_safety_sub".localized, iconName: "shield.fill", iconColor: .green)
            },
            content: {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12, alignment: .top),
                    GridItem(.flexible(), spacing: 12, alignment: .top),
                    GridItem(.flexible(), spacing: 12, alignment: .top),
                ], alignment: .leading, spacing: 12) {
                    privacyItem("lock.shield.fill", color: .green, title: "settings_privacy_item_1_title".localized, desc: "settings_privacy_item_1_desc".localized)
                    privacyItem("network", color: .blue, title: "settings_privacy_item_2_title".localized, desc: "settings_privacy_item_2_desc".localized)
                    privacyItem("trash.fill", color: .teal, title: "settings_privacy_item_3_title".localized, desc: "settings_privacy_item_3_desc".localized)
                    privacyItem("checkmark.seal.fill", color: .purple, title: "settings_privacy_item_4_title".localized, desc: "settings_privacy_item_4_desc".localized)
                    privacyItem("exclamationmark.shield.fill", color: .orange, title: "settings_privacy_item_5_title".localized, desc: "settings_privacy_item_5_desc".localized)
                    privacyItem("cpu.fill", color: .pink, title: "settings_privacy_item_6_title".localized, desc: "settings_privacy_item_6_desc".localized)
                    privacyItem("hand.raised.fill", color: .yellow, title: "settings_privacy_item_7_title".localized, desc: "settings_privacy_item_7_desc".localized)
                    privacyItem("xmark.app.fill", color: .indigo, title: "settings_privacy_item_8_title".localized, desc: "settings_privacy_item_8_desc".localized)
                    privacyItem("key.fill", color: .cyan, title: "settings_privacy_item_9_title".localized, desc: "settings_privacy_item_9_desc".localized)
                }
            }
        )
    }

    private func privacyItem(_ icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
