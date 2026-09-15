import Foundation

/// Tracks TCC-protected user folder access (Desktop / Downloads / Documents).
///
/// macOS shows a system permission dialog the first time the app enumerates one of
/// these folders, and re-prompts on later attempts after a denial. To keep that to a
/// single, well-explained moment:
/// - the onboarding / settings UI calls `refresh(_:)` from an explicit "Grant" button;
/// - the cleanup engine only probes folders whose state is `.notDetermined`, and never
///   re-probes a folder the user denied (persisted), so prompts never repeat.
public final class FolderAccessManager: @unchecked Sendable {
    public static let shared = FolderAccessManager()

    public enum Folder: String, CaseIterable, Sendable {
        case desktop
        case downloads
        case documents

        public var name: String {
            switch self {
            case .desktop: return "Desktop"
            case .downloads: return "Downloads"
            case .documents: return "Documents"
            }
        }

        public var homeRelativePath: String {
            "\(NSHomeDirectory())/\(name)"
        }
    }

    public enum Status: Equatable, Sendable {
        case granted
        case denied
        case notDetermined
    }

    private let lock = NSLock()
    private let askedKeyPrefix = "com.macpulse.folderAccessAsked."
    private let grantedKeyPrefix = "com.macpulse.folderAccessGranted."

    private init() {}

    // MARK: - State

    public func status(_ folder: Folder) -> Status {
        // Full Disk Access implicitly grants access to all user folders without prompts
        if PermissionsManager.checkFullDiskAccess() {
            return .granted
        }
        lock.lock()
        defer { lock.unlock() }
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: askedKeyPrefix + folder.rawValue) != nil else {
            return .notDetermined
        }
        return defaults.bool(forKey: grantedKeyPrefix + folder.rawValue) ? .granted : .denied
    }

    public func isGranted(_ folder: Folder) -> Bool {
        if PermissionsManager.checkFullDiskAccess() {
            return true
        }
        return status(folder) == .granted
    }

    public func allGranted() -> Bool {
        if PermissionsManager.checkFullDiskAccess() {
            return true
        }
        return Folder.allCases.allSatisfy { isGranted($0) }
    }

    // MARK: - Probing (may trigger the system prompt on first ever access)

    /// Attempts one access to `folder`. The very first call may surface the system
    /// permission dialog; later calls after a denial do NOT re-prompt (state is
    /// remembered instead). Returns whether access is granted afterwards.
    /// `rootPath` overrides the probed path (used by tests with isolated homes).
    @discardableResult
    public func refresh(_ folder: Folder, rootPath: String? = nil) -> Bool {
        if PermissionsManager.checkFullDiskAccess() {
            return true
        }
        // A previously denied folder is never re-probed — that is what causes the
        // "ask again and again" behavior.
        guard status(folder) != .denied else { return false }

        let fm = FileManager.default
        let path = rootPath ?? folder.homeRelativePath
        let granted: Bool
        if fm.fileExists(atPath: path) {
            granted = (try? fm.contentsOfDirectory(atPath: path)) != nil
        } else {
            granted = false
        }

        setGranted(folder, granted)
        return granted
    }

    /// Directly records the granted state (test hook / settings reset).
    public func setGranted(_ folder: Folder, _ granted: Bool) {
        lock.lock()
        defer { lock.unlock() }
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: askedKeyPrefix + folder.rawValue)
        defaults.set(granted, forKey: grantedKeyPrefix + folder.rawValue)
    }

    /// Resets remembered state (used by Settings "Reset permissions").
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        let defaults = UserDefaults.standard
        for folder in Folder.allCases {
            defaults.removeObject(forKey: askedKeyPrefix + folder.rawValue)
            defaults.removeObject(forKey: grantedKeyPrefix + folder.rawValue)
        }
    }
}
