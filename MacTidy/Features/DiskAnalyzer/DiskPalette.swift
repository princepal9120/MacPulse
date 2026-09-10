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

/// Disk visualization palette providing pastel and categorized hues
/// that match the DiskBuddy paper / warm UI style.
public enum DiskPalette {
    // Pastel folder tones (soft sage, sky, lavender, peach, sand, rose, mint, wheat)
    public static let pastelFolderColors: [Color] = [
        Color(red: 0.93, green: 0.82, blue: 0.76), // Peach / Sand
        Color(red: 0.80, green: 0.87, blue: 0.94), // Soft Sky
        Color(red: 0.82, green: 0.88, blue: 0.82), // Soft Sage
        Color(red: 0.94, green: 0.83, blue: 0.88), // Blush / Rose
        Color(red: 0.88, green: 0.85, blue: 0.93), // Lavender
        Color(red: 0.95, green: 0.90, blue: 0.78), // Wheat
        Color(red: 0.78, green: 0.90, blue: 0.88), // Mint
        Color(red: 0.90, green: 0.86, blue: 0.80), // Warm Khaki
        Color(red: 0.85, green: 0.88, blue: 0.95), // Periwinkle
        Color(red: 0.95, green: 0.86, blue: 0.82)  // Coral Pastel
    ]

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
        let index = abs(key.hashValue) % pastelFolderColors.count
        return pastelFolderColors[index]
    }

    public static func typeColor(for item: DiskItem) -> Color {
        if item.isDirectory && !item.isPackage {
            return folderColor(for: item)
        }
        return typeColor(for: item.fileType)
    }

    public static func typeColor(for category: FileCategory) -> Color {
        switch category {
        case .video: return Color(red: 0.92, green: 0.45, blue: 0.60) // Rose / Video
        case .audio: return Color(red: 0.60, green: 0.50, blue: 0.88) // Purple / Audio
        case .photo: return Color(red: 0.45, green: 0.75, blue: 0.95) // Cyan / Image
        case .docs: return Color(red: 0.95, green: 0.68, blue: 0.35)  // Amber / Doc
        case .apps: return Color(red: 0.40, green: 0.78, blue: 0.65)  // Green / Dev & Apps
        case .archives: return Color(red: 0.75, green: 0.60, blue: 0.45)// Brown / Archive
        case .all: return Color.gray.opacity(0.6)
        }
    }

    public static func ageColor(for item: DiskItem) -> Color {
        guard let date = item.modifiedAt else { return Color.gray.opacity(0.5) }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        switch days {
        case 0...7:
            return Color(red: 0.40, green: 0.72, blue: 0.55) // Fresh green
        case 8...30:
            return Color(red: 0.55, green: 0.75, blue: 0.85) // Cool blue
        case 31...90:
            return Color(red: 0.95, green: 0.75, blue: 0.45) // Tan / yellow
        case 91...365:
            return Color(red: 0.92, green: 0.58, blue: 0.38) // Warm orange
        default:
            return Color(red: 0.88, green: 0.42, blue: 0.42) // Old rust / red
        }
    }
}
