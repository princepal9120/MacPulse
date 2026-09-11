import Foundation
import SwiftUI

/// Where a file's last-write date falls relative to now.
public enum AgeBucket: String, CaseIterable, Identifiable, Sendable {
    case week
    case month
    case quarter
    case year
    case twoYears
    case ancient

    public var id: String { rawValue }

    /// Upper bound in days. `nil` means everything older than the previous bucket.
    var maxDays: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        case .twoYears: return 730
        case .ancient: return nil
        }
    }

    public var localizedName: String {
        switch self {
        case .week: return "age_bucket_week".localized
        case .month: return "age_bucket_month".localized
        case .quarter: return "age_bucket_quarter".localized
        case .year: return "age_bucket_year".localized
        case .twoYears: return "age_bucket_two_years".localized
        case .ancient: return "age_bucket_ancient".localized
        }
    }

    /// Fresh files read cool, forgotten ones read warm.
    public var color: Color {
        switch self {
        case .week: return .teal
        case .month: return .green
        case .quarter: return .yellow
        case .year: return .orange
        case .twoYears: return .pink
        case .ancient: return .red
        }
    }

    static func bucket(forDaysOld days: Int) -> AgeBucket {
        for bucket in AgeBucket.allCases {
            if let maxDays = bucket.maxDays, days <= maxDays { return bucket }
        }
        return .ancient
    }
}

public struct DiskAgeReport: Sendable {
    public struct Slice: Identifiable, Sendable {
        public let bucket: AgeBucket
        public let bytes: Int64
        public let fileCount: Int
        public var id: String { bucket.rawValue }
    }

    public struct MonthPoint: Identifiable, Sendable {
        public let start: Date
        public let bytes: Int64
        public var id: TimeInterval { start.timeIntervalSince1970 }
    }

    public let slices: [Slice]
    public let months: [MonthPoint]
    public let bigAndUntouched: [DiskItem]
    public let totalBytes: Int64
    public let datedFileCount: Int

    public var untouchedBytes: Int64 {
        bigAndUntouched.reduce(0) { $0 + $1.size }
    }

    public var heaviestSliceBytes: Int64 {
        slices.map(\.bytes).max() ?? 0
    }

    public var heaviestMonthBytes: Int64 {
        months.map(\.bytes).max() ?? 0
    }

    public var isEmpty: Bool { datedFileCount == 0 }
}

/// Splits a scanned tree by last-write date and surfaces the large files
/// nobody has touched in a year.
public struct DiskAgeAnalyzer: Sendable {
    /// A file has to be worth reclaiming before it earns a place in the list.
    public static let bigFileThreshold: Int64 = 100 * 1024 * 1024
    public static let untouchedDays = 365
    /// Enough to act on; the whole tail would just be scroll.
    public static let maxUntouchedListed = 200
    private static let heatmapMonths = 24

    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func analyze(root: DiskItem, now: Date = Date()) -> DiskAgeReport {
        var bytesPerBucket: [AgeBucket: Int64] = [:]
        var countPerBucket: [AgeBucket: Int] = [:]
        var bytesPerMonth: [Date: Int64] = [:]
        var untouched: [DiskItem] = []
        var totalBytes: Int64 = 0
        var datedFileCount = 0

        let monthStarts = recentMonthStarts(endingAt: now)
        let oldestTrackedMonth = monthStarts.first ?? now

        // Iterative walk: a deep home directory would blow the stack on recursion.
        var stack: [DiskItem] = [root]
        while let item = stack.popLast() {
            if item.isDirectory && !item.isPackage {
                stack.append(contentsOf: item.children ?? [])
                continue
            }

            guard let modified = item.modifiedAt else { continue }
            let days = calendar.dateComponents([.day], from: modified, to: now).day ?? 0
            let bucket = AgeBucket.bucket(forDaysOld: max(0, days))

            bytesPerBucket[bucket, default: 0] += item.size
            countPerBucket[bucket, default: 0] += 1
            totalBytes += item.size
            datedFileCount += 1

            if modified >= oldestTrackedMonth {
                let monthStart = calendar.dateInterval(of: .month, for: modified)?.start
                if let monthStart {
                    bytesPerMonth[monthStart, default: 0] += item.size
                }
            }

            if item.size >= Self.bigFileThreshold && days >= Self.untouchedDays {
                untouched.append(item)
            }
        }

        let slices = AgeBucket.allCases.map { bucket in
            DiskAgeReport.Slice(
                bucket: bucket,
                bytes: bytesPerBucket[bucket] ?? 0,
                fileCount: countPerBucket[bucket] ?? 0
            )
        }

        let months = monthStarts.map { start in
            DiskAgeReport.MonthPoint(start: start, bytes: bytesPerMonth[start] ?? 0)
        }

        untouched.sort { $0.size > $1.size }

        return DiskAgeReport(
            slices: slices,
            months: months,
            bigAndUntouched: Array(untouched.prefix(Self.maxUntouchedListed)),
            totalBytes: totalBytes,
            datedFileCount: datedFileCount
        )
    }

    /// Oldest first, so the heatmap reads left to right like a timeline.
    private func recentMonthStarts(endingAt now: Date) -> [Date] {
        guard let thisMonth = calendar.dateInterval(of: .month, for: now)?.start else { return [] }
        return (0..<Self.heatmapMonths).reversed().compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: thisMonth)
        }
    }
}
