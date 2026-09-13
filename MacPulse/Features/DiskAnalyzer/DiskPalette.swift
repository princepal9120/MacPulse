import SwiftUI

/// Coloring modes for disk visualizations matching the screenshot controls.
public enum ColoringMode: String, CaseIterable, Identifiable, Sendable {
    case byType
    case byFolder
    case byAge

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .byType: return "By type"
        case .byFolder: return "By folder"
        case .byAge: return "By age"
        }
    }

    public var icon: String {
        switch self {
        case .byType: return "square.grid.2x2"
        case .byFolder: return "folder"
        case .byAge: return "clock"
        }
    }
}

/// Disk visualization palette providing vibrant, high-contrast, dark-mode native hues
/// tuned for modern macOS Liquid Glass and dark backgrounds.
public enum DiskPalette {
    // 16 rich, vibrant, high-contrast hues with distinct chromatic separation
    public static let folderColors: [Color] = [
        Color(red: 0.17, green: 0.50, blue: 1.00), // Sapphire Blue
        Color(red: 0.00, green: 0.78, blue: 0.68), // Bright Teal
        Color(red: 0.62, green: 0.38, blue: 0.98), // Electric Violet
        Color(red: 0.98, green: 0.64, blue: 0.12), // Warm Amber
        Color(red: 0.94, green: 0.28, blue: 0.52), // Neon Rose
        Color(red: 0.12, green: 0.74, blue: 0.96), // Vivid Cyan
        Color(red: 0.48, green: 0.80, blue: 0.18), // Crisp Lime
        Color(red: 0.98, green: 0.46, blue: 0.20), // Sunset Orange
        Color(red: 0.42, green: 0.44, blue: 0.98), // Royal Indigo
        Color(red: 0.86, green: 0.28, blue: 0.92), // Radiant Magenta
        Color(red: 0.16, green: 0.84, blue: 0.56), // Emerald Mint
        Color(red: 0.88, green: 0.56, blue: 0.30), // Warm Ochre
        Color(red: 0.28, green: 0.62, blue: 0.96), // Sky Azure
        Color(red: 0.92, green: 0.22, blue: 0.38), // Crimson Ruby
        Color(red: 0.94, green: 0.76, blue: 0.14), // Golden Topaz
        Color(red: 0.74, green: 0.46, blue: 0.96)  // Lavender Flame
    ]

    // Backwards-compatible alias for existing references
    public static var pastelFolderColors: [Color] { folderColors }

    public static func color(for item: DiskItem, mode: ColoringMode = .byFolder) -> Color {
        switch mode {
        case .byFolder:
            return folderColor(for: item)
        case .byType:
            return typeColor(for: item)
        case .byAge:
            return ageColor(for: item)
        }
    }

    public static func folderColor(for item: DiskItem) -> Color {
        let key = item.isDirectory ? item.name : item.url.deletingLastPathComponent().lastPathComponent
        // djb2 hash distribution ensures adjacent directories receive diverse hues
        var hash: UInt = 5381
        for byte in key.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt(byte)
        }
        let index = Int(hash % UInt(folderColors.count))
        return folderColors[index]
    }

    public static func typeColor(for item: DiskItem) -> Color {
        if item.isDirectory && !item.isPackage {
            return folderColor(for: item)
        }
        return typeColor(for: item.fileType)
    }

    public static func typeColor(for category: FileCategory) -> Color {
        switch category {
        case .video: return Color(red: 0.94, green: 0.28, blue: 0.55) // Vibrant Rose / Video
        case .audio: return Color(red: 0.62, green: 0.40, blue: 0.98) // Electric Purple / Audio
        case .photo: return Color(red: 0.12, green: 0.74, blue: 0.98) // Cyan Blue / Photo
        case .docs: return Color(red: 0.98, green: 0.66, blue: 0.14)  // Amber Gold / Docs
        case .apps: return Color(red: 0.16, green: 0.82, blue: 0.58)  // Emerald / Apps
        case .archives: return Color(red: 0.88, green: 0.54, blue: 0.30)// Ochre / Archives
        case .all: return Color(white: 0.55)
        }
    }

    public static func ageColor(for item: DiskItem) -> Color {
        guard let date = item.modifiedAt else { return Color.gray.opacity(0.5) }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        switch days {
        case 0...7:
            return Color(red: 0.16, green: 0.82, blue: 0.56) // Recent (< 1 week): Fresh Mint
        case 8...30:
            return Color(red: 0.14, green: 0.72, blue: 0.96) // 1 Month: Vivid Cyan
        case 31...90:
            return Color(red: 0.98, green: 0.74, blue: 0.14) // 3 Months: Amber Gold
        case 91...365:
            return Color(red: 0.98, green: 0.46, blue: 0.20) // 1 Year: Sunset Orange
        default:
            return Color(red: 0.92, green: 0.26, blue: 0.36) // Older: Ruby Red
        }
    }
}
