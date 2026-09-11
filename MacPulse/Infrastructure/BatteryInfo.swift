import Foundation
import IOKit
import IOKit.ps

public struct BatterySnapshot: Sendable {
    var isPresent = false
    var percentage: Double = 0
    var isCharging = false
    var timeToEmptyMinutes: Int?
    var timeToFullMinutes: Int?
    var cycleCount: Int?
    var designCapacity: Int?
    var maxCapacity: Int?
    var temperatureCelsius: Double?

    var healthPercent: Double? {
        guard let design = designCapacity, design > 0, let maxCap = maxCapacity else { return nil }
        return min(100, Double(maxCap) / Double(design) * 100)
    }
}

/// Reads real battery state via public IOKit power-source APIs. Read-only, no entitlement needed.
enum BatteryReader {
    static func read() -> BatterySnapshot {
        var snap = BatterySnapshot()
        guard let blobUnmanaged = IOPSCopyPowerSourcesInfo() else { return snap }
        let blob = blobUnmanaged.takeRetainedValue()
        guard let listUnmanaged = IOPSCopyPowerSourcesList(blob) else { return snap }
        let sourcesList = listUnmanaged.takeRetainedValue() as [CFTypeRef]
        guard let firstSource = sourcesList.first,
              let descUnmanaged = IOPSGetPowerSourceDescription(blob, firstSource),
              let desc = descUnmanaged.takeUnretainedValue() as? [String: AnyObject]
        else { return snap }

        snap.isPresent = true
        let current = desc[kIOPSCurrentCapacityKey as String] as? Int ?? 0
        let maxCap = desc[kIOPSMaxCapacityKey as String] as? Int ?? 100
        snap.percentage = maxCap > 0 ? Double(current) / Double(maxCap) * 100 : 0
        snap.isCharging = (desc[kIOPSIsChargingKey as String] as? Bool) ?? false
        if let ttf = desc[kIOPSTimeToFullChargeKey as String] as? Int, ttf >= 0 { snap.timeToFullMinutes = ttf }
        if let tte = desc[kIOPSTimeToEmptyKey as String] as? Int, tte >= 0 { snap.timeToEmptyMinutes = tte }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            defer { IOObjectRelease(service) }
            var propsUnmanaged: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &propsUnmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = propsUnmanaged?.takeRetainedValue() as? [String: AnyObject] {
                snap.cycleCount = dict["CycleCount"] as? Int
                snap.designCapacity = dict["DesignCapacity"] as? Int
                snap.maxCapacity = (dict["MaxCapacity"] as? Int) ?? (dict["AppleRawMaxCapacity"] as? Int)
                if let raw = dict["Temperature"] as? Int {
                    snap.temperatureCelsius = Double(raw) / 100.0
                }
            }
        }
        return snap
    }
}
