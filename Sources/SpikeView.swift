//
//  SpikeView.swift
//  Burrow
//
//  Spike forensics (roadmap A.1): drag-select a window on a History chart and
//  see the top processes for that exact range. The selection is captured by a
//  chartOverlay drag in HistoryView; this sheet renders the result via the
//  already-tested MetricsStore.processWindow — GUI and MCP share one impl.
//
//  NOTE (hand-test): compile-verified only. Verify the drag maps to the right
//  timestamps and the ranked list matches.
//

import SwiftUI

/// A drag-selected window on the History chart, in unix seconds.
struct SpikeWindow: Identifiable {
    let id = UUID()
    let since: Int
    let until: Int
}

struct SpikeSheet: View {
    let db: DB
    let window: SpikeWindow
    let onClose: () -> Void

    @State private var rows: [(name: String, peakCPU: Double, peakMem: Double)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(NSLocalizedString("Top processes in selection", comment: "")).font(.headline)
                Spacer()
                Button(NSLocalizedString("Done", comment: "")) { onClose() }
            }
            Text(rangeLabel).font(.caption).foregroundStyle(.secondary)
            if rows.isEmpty {
                Text(NSLocalizedString("No process samples in that window.", comment: ""))
                    .foregroundStyle(.secondary).padding(.top, 8)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                            HStack {
                                Text(r.name)
                                Spacer()
                                Text(String(format: "%.0f%% CPU", r.peakCPU))
                                    .font(.body.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 400, height: 380)
        .task { load() }
    }

    private var rangeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm"
        let a = f.string(from: Date(timeIntervalSince1970: TimeInterval(window.since)))
        let b = f.string(from: Date(timeIntervalSince1970: TimeInterval(window.until)))
        return "\(a) – \(b)"
    }

    private func load() {
        let pw = MetricsStore(db: db).processWindow(.init(since: window.since, until: window.until))
        rows = pw.ranked(by: .peakCPU, limit: 12).map {
            (name: $0.name, peakCPU: $0.peakCPU, peakMem: $0.peakMem)
        }
    }
}
