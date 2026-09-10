import SwiftUI

/// One settings pane. Categories are rows in the app sidebar, so this view owns
/// only the pane body plus the cross-category search that can jump between panes.
struct SettingsDetailView: View {
    let category: SettingsCategory
    @Bindable var settings: AppSettings
    let permissionsManager: PermissionsManager
    @Binding var availableUpdate: AvailableUpdate?
    let onForget: () -> Void
    let onSelectCategory: (SettingsCategory) -> Void

    @State private var searchText: String = ""

    /// Settings read as a column, not a wall — cards stop growing on wide windows.
    private let contentMaxWidth: CGFloat = 860

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            Group {
                if searchText.isEmpty {
                    pane
                } else {
                    searchResults
                }
            }
            .frame(maxWidth: contentMaxWidth)

            Spacer(minLength: 0)
        }
        .searchable(text: $searchText, prompt: Text("settings_search_prompt".localized))
    }

    // MARK: - Pane

    @ViewBuilder
    private var pane: some View {
        switch category {
        case .general:
            SettingsGeneralView(
                settings: settings,
                permissionsManager: permissionsManager,
                availableUpdate: $availableUpdate,
                onForget: onForget
            )
        case .automation:
            SettingsAutomationView(settings: settings)
        case .advanced:
            SettingsAdvancedView(settings: settings)
        case .about:
            SettingsAboutView()
        }
    }

    // MARK: - Search Results

    private var searchResults: some View {
        let results = SettingsSearchRegistry.search(searchText)
        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(format: "settings_search_results_title".localized, searchText))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                if results.isEmpty {
                    ContentUnavailableView(
                        "settings_search_no_results".localized,
                        systemImage: "magnifyingglass",
                        description: Text("settings_search_no_results_sub".localized)
                    )
                } else {
                    ForEach(results) { item in
                        searchResultRow(item)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func searchResultRow(_ item: SettingsItem) -> some View {
        Button {
            searchText = ""
            onSelectCategory(item.category)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.iconName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(item.category.iconColor)
                    .frame(width: 30, height: 30)
                    .background(item.category.iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 8)

                StatusPill(item.category.displayName, iconName: item.category.iconName, style: .neutral, size: .small)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsDetailView(
        category: .general,
        settings: AppSettings(),
        permissionsManager: PermissionsManager(),
        availableUpdate: .constant(AvailableUpdate(version: "2.3.0", dmgURL: nil)),
        onForget: {},
        onSelectCategory: { _ in }
    )
}
