//
//  ScrollHelpers.swift
//  Burrow / Components
//
//  SwiftUI exposes no scroller styling, so we reach the enclosing
//  NSScrollView and switch it to the overlay style — thin, auto-hiding,
//  theme-aware. A no-op if the backing view isn't an NSScrollView, so it's
//  safe to attach to any scroll content.
//

import AppKit
import SwiftUI

private struct OverlayScrollers: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            var v: NSView? = nsView.superview
            while let cur = v, !(cur is NSScrollView) { v = cur.superview }
            guard let sv = v as? NSScrollView else { return }
            sv.scrollerStyle = .overlay
            sv.verticalScroller?.controlSize = .small
            sv.horizontalScroller?.controlSize = .small
        }
    }
}

extension View {
    /// Switch the enclosing scroll view to thin, auto-hiding overlay
    /// scrollers. Attach to content *inside* a ScrollView.
    func overlayScrollers() -> some View { background(OverlayScrollers()) }
}
