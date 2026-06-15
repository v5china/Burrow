//
//  TuneUpView.swift
//  Burrow
//
//  Tune-Up pane (roadmap F / #77): gathers recommendations, splits them into a
//  one-click *safe set* (reversible cache clears) and a *review set*
//  (destructive / behaviour-changing, e.g. startup items), via the tested
//  TuneUp selection logic. v1 sources: dev-ecosystem caches + controllable
//  startup items.
//
//  NOTE (hand-test): compile-verified only. Verify the scan, the reclaimable
//  total, and that "Run safe set" only trashes caches (reversible).
//

import SwiftUI
import AppKit

struct TuneUpView: View {
    private struct Row: Identifiable {
        let id = UUID()
        let rec: TuneUp.Recommendation
        let path: String?   // freeCache rows carry the dir to trash
    }

    @State private var rows: [Row] = []
    @State private var scanning = true

    var body: some View {
        let safeRows = rows.filter { $0.rec.safe }
        let reviewRows = rows.filter { !$0.rec.safe }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("Tune-Up", comment: "")).font(.title2.bold())
                if scanning { ProgressView().controlSize(.small) }

                if !safeRows.isEmpty {
                    HStack {
                        Text(NSLocalizedString("Safe to run", comment: "")).font(.headline)
                        Spacer()
                        Text(Fmt.bytes(TuneUp.reclaimable(safeRows.map(\.rec))))
                            .font(.body.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    ForEach(safeRows) { row($0) }
                    Button(NSLocalizedString("Run safe set", comment: "")) { runSafe(safeRows) }
                        .buttonStyle(.borderedProminent).padding(.top, 4)
                }

                if !reviewRows.isEmpty {
                    Text(NSLocalizedString("Needs review", comment: "")).font(.headline).padding(.top, 10)
                    ForEach(reviewRows) { row($0) }
                }

                if !scanning, rows.isEmpty {
                    Text(NSLocalizedString("Nothing to tune up — you're clean.", comment: ""))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .task { await gather() }
    }

    @ViewBuilder private func row(_ r: Row) -> some View {
        HStack {
            Text(r.rec.title)
            Spacer()
            if r.rec.bytes > 0 {
                Text(Fmt.bytes(r.rec.bytes)).font(.body.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
    }

    private func gather() async {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let found = await Task.detached(priority: .utility) { () -> [Row] in
            var out: [Row] = []
            for eco in DevHygiene.catalog(home: home) {
                for path in eco.paths where FileManager.default.fileExists(atPath: path) {
                    let bytes = DevHygiene.directorySize(path)
                    if bytes > 200_000_000 {  // only surface caches worth clearing
                        out.append(Row(rec: .init(
                            kind: .freeCache,
                            title: String(format: NSLocalizedString("Clear %@ cache", comment: ""), eco.name),
                            bytes: bytes), path: path))
                    }
                }
            }
            for item in StartupInventory.scanLive() where item.controllable {
                out.append(Row(rec: .init(
                    kind: .disableStartupItem,
                    title: String(format: NSLocalizedString("Review startup item: %@", comment: ""), item.label),
                    bytes: 0), path: nil))
            }
            return out.sorted { $0.rec.bytes > $1.rec.bytes }
        }.value
        rows = found
        scanning = false
    }

    private func runSafe(_ safeRows: [Row]) {
        for r in safeRows {
            if let p = r.path {
                try? FileManager.default.trashItem(at: URL(fileURLWithPath: p), resultingItemURL: nil)
            }
        }
        Task { await gather() }
    }
}
