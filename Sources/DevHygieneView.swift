//
//  DevHygieneView.swift
//  Burrow
//
//  Dev hygiene Home section (roadmap C.9). Each developer ecosystem's
//  cache/artifact roots that exist on disk, grouped under one Brand card per
//  ecosystem (icon + name + total), biggest ecosystem first, with per-path
//  size, reveal-in-Finder, and a move-to-Trash. Read-only scan off the main
//  thread; clearing trashes a single root (reversible).
//
//  NOTE (hand-test): compile-verified only. Verify sizes look right, the scan
//  stays off the main thread on a machine with large caches, and Clear trashes
//  exactly the named root.
//

import SwiftUI
import AppKit

struct DevHygieneView: View {
    private struct PathRow: Identifiable {
        let id = UUID()
        let path: String
        let bytes: Int64
    }
    private struct Group: Identifiable {
        let id = UUID()
        let ecosystem: String
        let glyph: String
        let paths: [PathRow]
        var total: Int64 { paths.reduce(0) { $0 + $1.bytes } }
    }

    @State private var groups: [Group] = []
    @State private var scanning = true
    @State private var clearTarget: PathRow?
    @State private var clearEcosystem: String = ""

    private var grandTotal: Int64 { groups.reduce(0) { $0 + $1.total } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if !scanning, groups.isEmpty {
                    emptyNote
                }
                ForEach(groups) { group in
                    ecosystemCard(group)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .task { await scan() }
        .confirmationDialog(
            NSLocalizedString("Move this cache to the Trash?", comment: ""),
            isPresented: Binding(get: { clearTarget != nil },
                                 set: { if !$0 { clearTarget = nil } }),
            presenting: clearTarget
        ) { r in
            Button(NSLocalizedString("Move to Trash", comment: ""), role: .destructive) {
                try? FileManager.default.trashItem(at: URL(fileURLWithPath: r.path), resultingItemURL: nil)
                Task { await scan() }
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
        } message: { r in
            Text("\(clearEcosystem) — \(Fmt.bytes(r.bytes))\n\(r.path)")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(NSLocalizedString("Dev hygiene", comment: ""))
                    .font(Brand.serif(26, .medium)).foregroundStyle(Brand.textPrimary)
                HStack(spacing: 7) {
                    if scanning {
                        ProgressView().controlSize(.small)
                        Text(NSLocalizedString("Scanning developer caches…", comment: ""))
                            .font(Brand.mono(11)).foregroundStyle(Brand.textSecondary)
                    } else if grandTotal > 0 {
                        Text(String(format: NSLocalizedString("%@ across %d ecosystems", comment: ""),
                                    Fmt.bytes(grandTotal), groups.count))
                            .font(Brand.mono(11)).foregroundStyle(Brand.textSecondary)
                    }
                }
            }
            Spacer()
        }
    }

    private var emptyNote: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 20)).foregroundStyle(Brand.green)
                Text(NSLocalizedString("No developer caches found.", comment: ""))
                    .font(Brand.sans(13)).foregroundStyle(Brand.textSecondary)
                Spacer()
            }
        }
    }

    private func ecosystemCard(_ group: Group) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 9) {
                    Image(systemName: group.glyph)
                        .font(.system(size: 14)).foregroundStyle(Brand.cream)
                        .frame(width: 22)
                    Text(group.ecosystem).font(Brand.sans(15, .semibold)).foregroundStyle(Brand.textPrimary)
                    Spacer()
                    Text(Fmt.bytes(group.total)).font(Brand.mono(13, .medium)).foregroundStyle(Brand.textPrimary)
                }
                if group.paths.count > 1 || group.paths.first?.path != group.ecosystem {
                    Rectangle().fill(Brand.hairline).frame(height: 1)
                }
                ForEach(group.paths) { r in
                    HStack(spacing: 10) {
                        Text(displayPath(r.path)).font(Brand.mono(11)).foregroundStyle(Brand.textSecondary)
                            .lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Text(Fmt.bytes(r.bytes)).font(Brand.mono(11)).foregroundStyle(Brand.textSecondary)
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: r.path)])
                        } label: {
                            Image(systemName: "magnifyingglass").font(.system(size: 11))
                                .foregroundStyle(Brand.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .help(NSLocalizedString("Reveal in Finder", comment: ""))
                        Button {
                            clearEcosystem = group.ecosystem
                            clearTarget = r
                        } label: {
                            Text(NSLocalizedString("Clear", comment: ""))
                                .font(Brand.sans(11, .semibold)).foregroundStyle(Tool.tuneup.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// Abbreviate the home prefix so the row reads as "~/Library/…".
    private func displayPath(_ p: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return p.hasPrefix(home) ? "~" + p.dropFirst(home.count) : p
    }

    private func scan() async {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let found = await Task.detached(priority: .utility) { () -> [Group] in
            var out: [Group] = []
            for eco in DevHygiene.catalog(home: home) {
                var rows: [PathRow] = []
                for path in eco.paths where FileManager.default.fileExists(atPath: path) {
                    let bytes = DevHygiene.directorySize(path)
                    if bytes > 0 { rows.append(PathRow(path: path, bytes: bytes)) }
                }
                if !rows.isEmpty {
                    rows.sort { $0.bytes > $1.bytes }
                    out.append(Group(ecosystem: eco.name, glyph: Self.glyph(for: eco.name), paths: rows))
                }
            }
            return out.sorted { $0.total > $1.total }
        }.value
        groups = found
        scanning = false
    }

    /// Best-fit SF Symbol per ecosystem — falls back to a generic drive.
    private static func glyph(for ecosystem: String) -> String {
        let n = ecosystem.lowercased()
        if n.contains("xcode") || n.contains("swift") || n.contains("derived") { return "hammer.fill" }
        if n.contains("homebrew") || n.contains("brew") { return "mug.fill" }
        if n.contains("node") || n.contains("npm") || n.contains("yarn") || n.contains("pnpm") { return "shippingbox.fill" }
        if n.contains("python") || n.contains("pip") || n.contains("conda") { return "chevron.left.forwardslash.chevron.right" }
        if n.contains("rust") || n.contains("cargo") { return "gearshape.fill" }
        if n.contains("go") { return "g.circle.fill" }
        if n.contains("docker") || n.contains("container") { return "cube.box.fill" }
        if n.contains("gradle") || n.contains("maven") || n.contains("java") { return "cup.and.saucer.fill" }
        if n.contains("ruby") || n.contains("gem") || n.contains("cocoapod") { return "diamond.fill" }
        if n.contains("cache") { return "tray.full.fill" }
        return "externaldrive.fill"
    }
}
