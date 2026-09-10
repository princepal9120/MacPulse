import Foundation

struct NetworkCounters: Sendable {
    var bytesIn: UInt64 = 0
    var bytesOut: UInt64 = 0
}

/// Cumulative byte counters across active, non-loopback interfaces via getifaddrs. Read-only, no entitlement needed.
enum NetworkThroughputReader {
    static func read() -> NetworkCounters {
        var counters = NetworkCounters()
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else { return counters }
        defer { freeifaddrs(ifaddrPtr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = cursor {
            defer { cursor = addr.pointee.ifa_next }
            let flags = Int32(addr.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0,
                  addr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK),
                  let data = addr.pointee.ifa_data else { continue }
            let networkData = data.assumingMemoryBound(to: if_data.self).pointee
            counters.bytesIn += UInt64(networkData.ifi_ibytes)
            counters.bytesOut += UInt64(networkData.ifi_obytes)
        }
        return counters
    }
}
