//
//  ReportView.swift
//  Burrow
//
//  The weekly-report Home section (roadmap A.4). Renders the digest from
//  ReportComposer/WeeklyReport — the same markdown burrow_report returns —
//  parsed into Brand cards: one card per section (Cleanup, Disk, Top energy,
//  Battery, Changes, New startup items), each with an icon, optional intro,
//  and styled bullet rows (bold/`code` preserved via AttributedString).
//
//  NOTE (hand-test): compile-verified only. Verify the cards render and the
//  forecast / top-energy lines populate against a real history DB.
//

import SwiftUI

struct ReportView: View {
    let db: DB

    private struct Section: Identifiable {
        let id = UUID()
        var title: String
        var intro: String?
        var bullets: [String]
    }

    @State private var caption: String = ""
    @State private var sections: [Section] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if sections.isEmpty {
                    emptyNote
                } else {
                    ForEach(sections) { sectionCard($0) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .task { reload() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(NSLocalizedString("Weekly report", comment: ""))
                .font(Brand.serif(26, .medium)).foregroundStyle(Brand.textPrimary)
            if !caption.isEmpty {
                Text(caption).font(Brand.mono(11)).foregroundStyle(Brand.textSecondary)
            }
        }
    }

    private var emptyNote: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass").font(.system(size: 18)).foregroundStyle(Brand.textSecondary)
                Text(NSLocalizedString("Not enough history yet — check back after a few days of monitoring.", comment: ""))
                    .font(Brand.sans(13)).foregroundStyle(Brand.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
    }

    private func sectionCard(_ s: Section) -> some View {
        let (glyph, color) = Self.style(for: s.title)
        return GlassCard {
            VStack(alignment: .leading, spacing: 9) {
                Eyebrow(text: s.title, glyph: glyph, color: color)
                if let intro = s.intro, !intro.isEmpty {
                    Text(attributed(intro)).font(Brand.sans(12)).foregroundStyle(Brand.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array(s.bullets.enumerated()), id: \.offset) { _, b in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle().fill(color.opacity(0.8)).frame(width: 4, height: 4)
                            .padding(.top, 5)
                        Text(attributed(b)).font(Brand.sans(13)).foregroundStyle(Brand.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    /// Render inline markdown (**bold**, `code`) — falls back to plain text.
    private func attributed(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s)) ?? AttributedString(s)
    }

    /// Icon + accent per known section title.
    private static func style(for title: String) -> (String, Color) {
        switch title.lowercased() {
        case "cleanup":          return ("sparkles", Tool.clean.accent)
        case "disk":             return ("internaldrive", Brand.blue)
        case "top energy users": return ("bolt.fill", Brand.amber)
        case "battery":          return ("battery.50", Brand.green)
        case "changes":          return ("waveform.path.ecg", Brand.orange)
        case "new startup items": return ("power", Brand.red)
        default:                 return ("doc.text", Brand.textSecondary)
        }
    }

    private func reload() {
        let md = WeeklyReport.markdown(
            ReportComposer.gather(metrics: MetricsStore(db: db), days: 7,
                                  now: Int(Date().timeIntervalSince1970)))
        parse(md)
    }

    /// Split the digest markdown into the caption + section cards.
    private func parse(_ md: String) {
        var cap = ""
        var built: [Section] = []
        var current: Section?

        func flush() {
            if let c = current { built.append(c) }
            current = nil
        }

        for raw in md.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("## ") {
                flush()
                current = Section(title: String(line.dropFirst(3)), intro: nil, bullets: [])
            } else if line.hasPrefix("# ") {
                continue   // page title — we render our own header
            } else if line.hasPrefix("_"), line.hasSuffix("_") {
                cap = String(line.dropFirst().dropLast())
            } else if line.hasPrefix("- ") {
                current?.bullets.append(String(line.dropFirst(2)))
            } else if current != nil, current?.bullets.isEmpty == true {
                // A non-bullet line right after a heading is the section intro.
                let existing = current?.intro ?? ""
                current?.intro = existing.isEmpty ? line : existing + " " + line
            }
        }
        flush()
        caption = cap
        sections = built
    }
}
