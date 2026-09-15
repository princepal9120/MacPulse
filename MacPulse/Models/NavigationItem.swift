import SwiftUI

extension Notification.Name {
    static let macPulseNavigate = Notification.Name("MacPulse.navigate")
    static let macPulseReplayOnboarding = Notification.Name("MacPulse.replayOnboarding")
    static let macPulseReopenMainWindow = Notification.Name("MacPulse.reopenMainWindow")
}

enum NavigationItem: String, CaseIterable, Identifiable, Hashable {
    case dashboard = "Dashboard"
    case cleanup = "Cleanup"
    case diskSpace = "Disk Space"
    case duplicates = "Duplicates"
    case processes = "Processes"
    case monitor = "Monitor"
    case privacy = "Privacy"
    case startupServices = "Startup Services"
    case uninstaller = "Uninstaller"

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .dashboard:      return "menu_dashboard".localized
        case .cleanup:        return "menu_cleanup".localized
        case .diskSpace:      return "menu_disk_space".localized
        case .duplicates:     return "menu_duplicates".localized
        case .processes:      return "menu_processes".localized
        case .monitor:        return "menu_monitor".localized
        case .privacy:        return "menu_privacy".localized
        case .startupServices: return "menu_startup_services".localized
        case .uninstaller:    return "menu_uninstaller".localized
        }
    }

    /// Subtitle shown under the window title.
    var localizedSubtitle: String? {
        switch self {
        case .dashboard:       return "dashboard_subtitle".localized
        case .cleanup:         return "cleanup_subtitle".localized
        case .diskSpace:       return "disk_space_subtitle".localized
        case .duplicates:      return "duplicates_subtitle".localized
        case .processes:       return "processes_subtitle".localized
        case .monitor:         return "monitor_subtitle".localized
        case .privacy:         return "privacy_subtitle".localized
        case .startupServices: return "startup_subtitle".localized
        case .uninstaller:     return "uninstaller_subtitle".localized
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "laptopcomputer"
        case .cleanup: return "sparkles"
        case .diskSpace: return "folder.fill"
        case .duplicates: return "square.on.square"
        case .processes: return "cpu"
        case .monitor: return "waveform.path.ecg"
        case .privacy: return "eye.trianglebadge.exclamationmark"
        case .startupServices: return "bolt.horizontal"
        case .uninstaller: return "trash"
        }
    }

    var tint: Color {
        switch self {
        case .dashboard: return .blue
        case .cleanup: return .teal
        case .diskSpace: return .orange
        case .duplicates: return .purple
        case .processes: return .pink
        case .monitor: return .green
        case .privacy: return .red
        case .startupServices: return .yellow
        case .uninstaller: return .red
        }
    }
}

/// One row in the app sidebar: either a feature screen or a settings pane.
/// Settings live in the same sidebar so there is never a second nested rail.
enum SidebarDestination: Hashable, Identifiable {
    case feature(NavigationItem)
    case setting(SettingsCategory)

    var id: String {
        switch self {
        case .feature(let item):     return "feature.\(item.rawValue)"
        case .setting(let category): return "setting.\(category.rawValue)"
        }
    }

    var localizedTitle: String {
        switch self {
        case .feature(let item):     return item.localizedTitle
        case .setting(let category): return category.displayName
        }
    }

    var localizedSubtitle: String? {
        switch self {
        case .feature(let item): return item.localizedSubtitle
        case .setting:           return "settings_subtitle".localized
        }
    }

    var systemImage: String {
        switch self {
        case .feature(let item):     return item.systemImage
        case .setting(let category): return category.iconName
        }
    }

    var tint: Color {
        switch self {
        case .feature(let item):     return item.tint
        case .setting(let category): return category.iconColor
        }
    }
}

/// Sidebar grouping: flat items plus titled sections.
struct SidebarSection: Identifiable {
    let titleKey: String?
    let items: [SidebarDestination]

    var id: String { titleKey ?? items.first?.id ?? "" }

    static let all: [SidebarSection] = [
        SidebarSection(titleKey: nil, items: [.feature(.dashboard)]),
        SidebarSection(
            titleKey: "sidebar_section_actions",
            items: [.feature(.cleanup), .feature(.diskSpace), .feature(.duplicates), .feature(.uninstaller)]
        ),
        SidebarSection(
            titleKey: "sidebar_section_insights",
            items: [.feature(.monitor), .feature(.privacy), .feature(.processes), .feature(.startupServices)]
        ),
        SidebarSection(
            titleKey: "menu_settings",
            items: SettingsCategory.visibleCases.map(SidebarDestination.setting)
        ),
    ]
}
