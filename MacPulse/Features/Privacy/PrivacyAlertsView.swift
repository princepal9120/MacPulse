import SwiftUI

struct PrivacyAlertsView: View {
    @ObservedObject var viewModel: PrivacyMonitorViewModel

    init(viewModel: PrivacyMonitorViewModel = PrivacyMonitorViewModel()) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("menu_privacy".localized, systemImage: "eye.trianglebadge.exclamationmark")
                    .font(.title2.bold())

                HStack(spacing: 16) {
                    statusCard(title: "Camera", active: viewModel.cameraActive, icon: "camera.fill")
                    statusCard(title: "Microphone", active: viewModel.micActive, icon: "mic.fill")
                }

                Text("privacy_recent_activity".localized).font(.headline)

                if viewModel.events.isEmpty {
                    emptyView
                } else {
                    eventList
                }

                Text("privacy_footer_note".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .task { viewModel.start() }
    }

    private func statusCard(title: String, active: Bool, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon).foregroundStyle(active ? .red : .secondary)
                Text(title).font(.headline)
                Spacer()
                Circle().fill(active ? Color.red : Color.green.opacity(0.6)).frame(width: 10, height: 10)
            }
            Text(active ? "privacy_in_use".localized : "privacy_idle".localized)
                .font(.subheadline)
                .foregroundStyle(active ? .red : .secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var eventList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.events) { event in
                HStack {
                    Image(systemName: event.device == "Camera" ? "camera.fill" : "mic.fill")
                        .foregroundStyle(event.isActive ? .red : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(event.device) — \(event.name)").font(.subheadline)
                        Text(event.startedAt, style: .time).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(event.isActive ? "privacy_active".localized : "privacy_ended".localized)
                        .font(.caption.bold())
                        .foregroundStyle(event.isActive ? .red : .secondary)
                }
                .padding(.vertical, 10)
                if event.id != viewModel.events.last?.id { Divider() }
            }
        }
        .padding(.horizontal)
        .glassCard()
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("privacy_empty_state".localized).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
