import Foundation
import Darwin

struct SystemMetrics: Sendable {
    var cpuPercent: Double = 0
    var memoryPercent: Double = 0
    var usedMemory: UInt64 = 0
    var totalMemory: UInt64 = 0
    var diskPercent: Double = 0
    var usedDisk: UInt64 = 0
    var totalDisk: UInt64 = 0
    var loadAverage: [Double] = []
    var updatedAt = Date()
}

@MainActor
final class MonitorViewModel: ObservableObject {
    @Published private(set) var metrics = SystemMetrics()
    @Published private(set) var isLoading = false
    private var task: Task<Void, Never>?

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stop() { task?.cancel(); task = nil }

    func refresh() async {
        isLoading = true
        let physical = ProcessInfo.processInfo.physicalMemory
        let vm = memoryUsage()
        let disk = diskUsage()
        var loads = [Double](repeating: 0, count: 3)
        _ = getloadavg(&loads, 3)
        let cores = Double(max(ProcessInfo.processInfo.activeProcessorCount, 1))
        metrics = SystemMetrics(
            cpuPercent: min(100, max(0, loads[0] / cores * 100)),
            memoryPercent: physical > 0 ? Double(vm.used) / Double(physical) * 100 : 0,
            usedMemory: vm.used, totalMemory: physical,
            diskPercent: disk.total > 0 ? Double(disk.used) / Double(disk.total) * 100 : 0,
            usedDisk: disk.used, totalDisk: disk.total,
            loadAverage: loads, updatedAt: Date()
        )
        isLoading = false
    }

    private func memoryUsage() -> (used: UInt64, free: UInt64) {
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        var info = vm_statistics64_data_t()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, 0) }
        let page = UInt64(vm_kernel_page_size)
        let free = UInt64(info.free_count + info.inactive_count) * page
        let total = ProcessInfo.processInfo.physicalMemory
        return (total > free ? total - free : 0, free)
    }

    private func diskUsage() -> (used: UInt64, total: UInt64) {
        guard let values = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]),
              let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacityForImportantUsage else { return (0, 0) }
        let t = UInt64(total), a = UInt64(max(0, available))
        return (t > a ? t - a : 0, t)
    }
}
