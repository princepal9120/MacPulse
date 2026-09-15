import Foundation
import AppKit
import os.log
import ApplicationServices
import Darwin

private extension Logger {
    static let permissions = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.macpulse", category: "PermissionsManager")
}

/// Manages file system permissions and guides users through granting access.
@Observable
public final class PermissionsManager {
    /// Whether the app has Full Disk Access.
    public private(set) var hasFullDiskAccess = false

    /// Whether the app has Accessibility access.
    public private(set) var hasAccessibility = false

    /// Whether the app has Automation (Apple Events) access.
    public private(set) var hasAutomation = false

    /// Whether Trash access was granted.
    public private(set) var hasTrashAccess = false

    /// Whether the guidance panel should be shown.
    public var showGuidance = false

    /// Whether the user has dismissed the guidance permanently.
    public private(set) var guidanceDismissed = false

    /// Whether Full Disk Access was ever granted (persisted across launches).
    public private(set) var fdaEverGranted = false

    private let userDefaultsKey = "com.macpulse.guidanceDismissed"
    private let fdaGrantedKey = "com.macpulse.fdaGranted"

    public init() {
        self.guidanceDismissed = UserDefaults.standard.bool(forKey: userDefaultsKey)
        self.fdaEverGranted = UserDefaults.standard.bool(forKey: fdaGrantedKey)
        self.hasFullDiskAccess = Self.checkFullDiskAccess()
        self.hasAccessibility = Self.checkAccessibility()
        self.hasAutomation = Self.checkAutomation()
        self.hasTrashAccess = Self.checkTrashAccess()
        persistFDAState()
    }

    /// Checks if the application has Full Disk Access by attempting to read protected paths.
    /// Uses non-prompting, standard paths that fail silently (EPERM) without showing system dialogs.
    public static func checkFullDiskAccess() -> Bool {
        let home = NSHomeDirectory()
        let fm = FileManager.default

        // 1. User TCC database — only readable with Full Disk Access (fails with EPERM silently otherwise)
        let userTCC = "\(home)/Library/Application Support/com.apple.TCC/TCC.db"
        let tccFd = open(userTCC, O_RDONLY)
        if tccFd >= 0 {
            close(tccFd)
            Logger.permissions.info("Full Disk Access check passed via user TCC.db")
            return true
        }

        // 2. Safari folder — protected by SystemPolicyAllFiles, listing contents fails silently without FDA
        let safari = "\(home)/Library/Safari"
        if fm.fileExists(atPath: safari) {
            if (try? fm.contentsOfDirectory(atPath: safari)) != nil {
                Logger.permissions.info("Full Disk Access check passed via ~/Library/Safari")
                return true
            }
        }

        // 3. Time Machine preferences — protected by SystemPolicyAllFiles
        let tmPlist = "/Library/Preferences/com.apple.TimeMachine.plist"
        let tmFd = open(tmPlist, O_RDONLY)
        if tmFd >= 0 {
            close(tmFd)
            Logger.permissions.info("Full Disk Access check passed via TimeMachine.plist")
            return true
        }

        // 4. User Mail folder — protected by SystemPolicyAllFiles
        let mail = "\(home)/Library/Mail"
        if fm.fileExists(atPath: mail) {
            if (try? fm.contentsOfDirectory(atPath: mail)) != nil {
                Logger.permissions.info("Full Disk Access check passed via ~/Library/Mail")
                return true
            }
        }

        Logger.permissions.info("Full Disk Access not granted")
        return false
    }
    
    /// Checks if the app has Accessibility (AX) access.
    nonisolated public static func checkAccessibility() -> Bool {
        AXIsProcessTrustedWithOptions(nil)
    }
    
    /// Checks if the app can send Apple Events (Automation).
    public static func checkAutomation() -> Bool {
        let script = NSAppleScript(source: "return \"ok\"")
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        let success = error == nil && result?.stringValue == "ok"
        Logger.permissions.info("Automation access: \(success ? "granted" : "denied")")
        return success
    }
    
    /// Checks if the app can access Trash.
    public static func checkTrashAccess() -> Bool {
        let fm = FileManager.default
        let trashURL = fm.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        return (try? fm.contentsOfDirectory(atPath: trashURL.path)) != nil
    }
    
    /// Refreshes all permission statuses.
    public func refresh() {
        hasFullDiskAccess = Self.checkFullDiskAccess()
        hasAccessibility = Self.checkAccessibility()
        hasAutomation = Self.checkAutomation()
        hasTrashAccess = Self.checkTrashAccess()
        persistFDAState()

        if hasFullDiskAccess && showGuidance {
            showGuidance = false
        }
    }

    /// Persists the Full Disk Access grant so the app remembers it across launches.
    private func persistFDAState() {
        if hasFullDiskAccess {
            fdaEverGranted = true
            UserDefaults.standard.set(true, forKey: fdaGrantedKey)
        }
    }
    
    /// Returns true if all critical permissions are granted.
    public var allCriticalPermissionsGranted: Bool {
        hasFullDiskAccess
    }
    
    /// Returns a list of missing permission descriptions.
    public var missingPermissions: [String] {
        var missing: [String] = []
        if !hasFullDiskAccess {
            missing.append("permissions.full_disk_access".localized)
        }
        if !hasAccessibility {
            missing.append("permissions.accessibility".localized)
        }
        if !hasAutomation {
            missing.append("permissions.automation".localized)
        }
        if !hasTrashAccess {
            missing.append("permissions.trash_access".localized)
        }
        return missing
    }
    
    /// Opens the Full Disk Access section in System Settings.
    public func openFullDiskAccessSettings() {
        // macOS 13+ (Ventura/Sonoma/Sequoia) URL scheme for Full Disk Access
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security"
        ]
        
        for urlString in urls {
            if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
                Logger.permissions.info("Opened Full Disk Access settings via: \(urlString, privacy: .public)")
                return
            }
        }
    }
    
    /// Opens Accessibility settings in System Settings.
    public func openAccessibilitySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security"
        ]
        for urlString in urls {
            if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
                Logger.permissions.info("Opened Accessibility settings via: \(urlString, privacy: .public)")
                return
            }
        }
    }
    
    /// Opens Automation settings in System Settings.
    public func openAutomationSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Automation",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
            "x-apple.systempreferences:com.apple.preference.security"
        ]
        for urlString in urls {
            if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
                Logger.permissions.info("Opened Automation settings via: \(urlString, privacy: .public)")
                return
            }
        }
    }
    
    /// Opens System Settings Privacy & Security main page.
    public func openPrivacySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
            "x-apple.systempreferences:com.apple.preference.security"
        ]
        for urlString in urls {
            if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
                Logger.permissions.info("Opened Privacy settings via: \(urlString, privacy: .public)")
                return
            }
        }
    }
    
    /// Shows the guidance panel to the user.
    public func showGuidanceIfNeeded() {
        guard !guidanceDismissed else { return }
        guard !hasFullDiskAccess else { return }
        showGuidance = true
    }
    
    /// Permanently dismisses the guidance (user preference).
    public func dismissGuidancePermanently() {
        guidanceDismissed = true
        showGuidance = false
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
        Logger.permissions.info("Guidance permanently dismissed by user")
    }
    
    /// Temporarily dismisses the guidance (will show again next launch).
    public func dismissGuidanceTemporarily() {
        showGuidance = false
    }

    /// Re-enables the permission guidance after a permanent dismissal and shows it,
    /// for when the user changes their mind (e.g. from Settings).
    public func requestGuidanceAgain() {
        guidanceDismissed = false
        UserDefaults.standard.set(false, forKey: userDefaultsKey)
        refresh()
        if !hasFullDiskAccess {
            showGuidance = true
        }
        Logger.permissions.info("Guidance re-enabled by user")
    }

    /// Reveals the application bundle in Finder so user can drag it directly into Full Disk Access.
    public func revealAppInFinder() {
        let bundleURL = Bundle.main.bundleURL
        NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
        Logger.permissions.info("Revealed MacPulse bundle in Finder")
    }
}
