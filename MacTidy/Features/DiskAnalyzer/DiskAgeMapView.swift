import SwiftUI

/// Where the bytes sit on a timeline, and the big files nobody has opened in a year.
struct DiskAgeMapView: View {
    let report: DiskAgeReport
    let selectedItem: DiskItem?
    let onSelect: (DiskItem) -> Void
    let onQuickLook: (DiskItem) -> Void
    let onShowInFinder: (DiskItem) -> Void
    let onTrash: (DiskItem) -> Void
    let onTrashAllUntouched: () -> Void

    @State private var showTrashAllConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if report.isEmpty {
                    emptyState
                } else {
                    ageBreakdown
                    monthHeatmap
                    bigAndUntouched
                }
            }
            .padding(4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 38, weight: .thin))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("age_map_empty".localized)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Bytes by age

    private var ageBreakdown: some View {
        GlassCard {
            SettingsSectionHeader(
                "age_map_breakdown_title".localized,
                subtitle: String(
                    format: "age_map_breakdown_subtitle".localized,
                    report.totalBytes.formattedByteCount(),
                    report.datedFileCount
                ),
                iconName: "chart.bar.fill",
                iconColor: .orange
            )

            VStack(spacing: 8) {
                ForEach(report.slices) { slice in
                    bucketRow(slice)
                }
            }
        }
    }

    private func bucketRow(_ slice: DiskAgeReport.Slice) -> some View {
        let fraction = report.heaviestSliceBytes > 0
            ? Double(slice.bytes) / Double(report.heaviestSliceBytes)
            : 0
        let share = report.totalBytes > 0
            ? Double(slice.bytes) / Double(report.totalBytes) * 100
            : 0

        return HStack(spacing: 10) {
            Text(slice.bucket.localizedName)
                .font(.callout)
                .frame(width: 130, alignment: .leading)
                .lineLimit(1)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                    Capsule()
                        .fill(slice.bucket.color.opacity(0.75))
                        .frame(width: max(2, geometry.size.width * fraction))
                }
            }
            .frame(height: 14)

            Text(slice.bytes.formattedByteCount())
                .font(.caption.monospacedDigit().weight(.semibold))
                .frame(width: 74, alignment: .trailing)

            Text(String(format: "%.0f%%", share))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
    }

    // MARK: - Last-modified heatmap

    private var monthHeatmap: some View {
        GlassCard {
            SettingsSectionHeader(
                "age_map_heatmap_title".localized,
                subtitle: "age_map_heatmap_subtitle".localized,
                iconName: "square.grid.3x3.fill",
                iconColor: .teal
            )

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 12), spacing: 4) {
                ForEach(report.months) { month in
                    monthCell(month)
                }
            }
        }
    }

    private func monthCell(_ month: DiskAgeReport.MonthPoint) -> some View {
        let intensity = report.heaviestMonthBytes > 0
            ? Double(month.bytes) / Double(report.heaviestMonthBytes)
            : 0

        return VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.accentColor.opacity(0.10 + intensity * 0.8))
                .frame(height: 30)
            Text(month.start.formatted(.dateTime.month(.narrow)))
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .help("\(month.start.formatted(.dateTime.month(.abbreviated).year())) — \(month.bytes.formattedByteCount())")
    }

    // MARK: - Big & untouched

    private var bigAndUntouched: some View {
        GlassCard {
            HStack(alignment: .top) {
                SettingsSectionHeader(
                    "age_map_untouched_title".localized,
                    subtitle: String(
                        format: "age_map_untouched_subtitle".localized,
                        DiskAgeAnalyzer.bigFileThreshold.formattedByteCount()
                    ),
                    iconName: "clock.badge.exclamationmark.fill",
                    iconColor: .pink
                )

                Spacer()

                if !report.bigAndUntouched.isEmpty {
                    Button(role: .destructive) {
                        showTrashAllConfirmation = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                            Text(String(
                                format: "age_map_stage_all".localized,
                                report.untouchedBytes.formattedByteCount()
                            ))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                }
            }

            if report.bigAndUntouched.isEmpty {
                Text("age_map_untouched_none".localized)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 2) {
                    ForEach(report.bigAndUntouched) { item in
                        untouchedRow(item)
                    }
                }
            }
        }
        .confirmationDialog(
            "age_map_stage_all_confirm_title".localized,
            isPresented: $showTrashAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("age_map_stage_all_confirm_action".localized, role: .destructive) {
                onTrashAllUntouched()
            }
            Button("cancel".localized, role: .cancel) {}
        } message: {
            Text(String(
                format: "age_map_stage_all_confirm_message".localized,
                report.bigAndUntouched.count,
                report.untouchedBytes.formattedByteCount()
            ))
        }
    }

    private func untouchedRow(_ item: DiskItem) -> some View {
        let isSelected = selectedItem?.id == item.id

        return HStack(spacing: 10) {
            Image(systemName: item.isPackage ? "shippingbox.fill" : "doc.fill")
                .foregroundStyle(DiskPalette.color(for: item))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.url.deletingLastPathComponent().path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if let modified = item.modifiedAt {
                Text(modified.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(item.size.formattedByteCount())
                .font(.caption.monospacedDigit().weight(.semibold))
                .frame(width: 74, alignment: .trailing)

            HStack(spacing: 2) {
                Button { onQuickLook(item) } label: { Image(systemName: "eye") }
                    .help("disk_analyzer_quick_look".localized)
                Button { onShowInFinder(item) } label: { Image(systemName: "folder") }
                    .help("disk_analyzer_open_folder".localized)
                Button { onTrash(item) } label: { Image(systemName: "trash") }
                    .help("delete_action".localized)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { onSelect(item) }
    }
}
