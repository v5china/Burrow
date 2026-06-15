//
//  ReportView.swift
//  Burrow
//
//  The weekly-report Home section (roadmap A.4). Renders the markdown from
//  ReportComposer/WeeklyReport — the same digest burrow_report returns. Styled
//  lightly with system type for now; Brand styling is a follow-up.
//
//  NOTE (hand-test): compile-verified only. Verify the section renders and the
//  forecast/top-energy lines populate against a real history DB.
//

import SwiftUI

struct ReportView: View {
    let db: DB
    @State private var lines: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    row(line)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .task { reload() }
    }

    @ViewBuilder private func row(_ line: String) -> some View {
        if line.hasPrefix("# ") {
            Text(String(line.dropFirst(2))).font(.title2.bold()).padding(.bottom, 2)
        } else if line.hasPrefix("## ") {
            Text(String(line.dropFirst(3))).font(.headline).padding(.top, 8)
        } else if line.hasPrefix("- ") {
            Text("•  " + strip(String(line.dropFirst(2)))).font(.body)
        } else if line.hasPrefix("_"), line.hasSuffix("_") {
            Text(String(line.dropFirst().dropLast())).font(.caption).foregroundStyle(.secondary)
        } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
            Text(strip(line)).font(.body)
        }
    }

    /// Drop the markdown bold markers we emit; the GUI shows weight via font.
    private func strip(_ s: String) -> String { s.replacingOccurrences(of: "**", with: "") }

    private func reload() {
        let md = WeeklyReport.markdown(
            ReportComposer.gather(metrics: MetricsStore(db: db), days: 7,
                                  now: Int(Date().timeIntervalSince1970)))
        lines = md.components(separatedBy: "\n")
    }
}
