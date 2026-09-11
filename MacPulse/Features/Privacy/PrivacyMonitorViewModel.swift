import Foundation
import AVFoundation
import Combine

struct PrivacyEvent: Identifiable, Sendable {
    let id = UUID()
    let device: String
    let name: String
    let startedAt: Date
    var endedAt: Date?

    var isActive: Bool { endedAt == nil }
}

/// Watches AVCaptureDevice's public, KVO-observable in-use flag — the same signal behind the system camera/mic indicators.
/// Does not open or access the camera/mic itself, so no capture permission is required.
@MainActor
public final class PrivacyMonitorViewModel: ObservableObject {
    @Published private(set) var cameraActive = false
    @Published private(set) var micActive = false
    @Published private(set) var events: [PrivacyEvent] = []

    private var cancellables: Set<AnyCancellable> = []
    private var activeEventIDs: [String: UUID] = [:]

    public init() {}

    public func start() {
        guard cancellables.isEmpty else { return }
        observe(mediaType: .video, label: "Camera")
        observe(mediaType: .audio, label: "Microphone")
    }

    private func observe(mediaType: AVMediaType, label: String) {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .microphone, .external, .continuityCamera],
            mediaType: mediaType,
            position: .unspecified
        )
        for device in session.devices {
            device.publisher(for: \.isInUseByAnotherApplication)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] inUse in
                    self?.handle(inUse: inUse, device: device, label: label)
                }
                .store(in: &cancellables)
        }
    }

    private func handle(inUse: Bool, device: AVCaptureDevice, label: String) {
        if label == "Camera" { cameraActive = inUse } else { micActive = inUse }

        let key = device.uniqueID
        if inUse {
            let event = PrivacyEvent(device: label, name: device.localizedName, startedAt: Date(), endedAt: nil)
            activeEventIDs[key] = event.id
            events.insert(event, at: 0)
            if events.count > 100 { events.removeLast() }
        } else if let id = activeEventIDs[key], let idx = events.firstIndex(where: { $0.id == id }) {
            events[idx].endedAt = Date()
            activeEventIDs[key] = nil
        }
    }
}
