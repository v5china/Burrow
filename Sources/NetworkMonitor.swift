//
//  NetworkMonitor.swift
//  Burrow
//
//  A dedicated, high-cadence network throughput reader. `mo status --json`
//  reports a network rate, but the sampler only runs it every 5–60 s, and
//  network traffic is far burstier than CPU/disk — so at that cadence the
//  chart is mostly flat with the occasional spike that happened to land on a
//  tick. This reads the interface byte counters natively (getifaddrs →
//  if_data) every second, completely decoupled from the mo poll, so the live
//  tile and its sparkline reflect what's actually happening on the wire.
//
//  Counters are cumulative since boot; the rate is their delta over time. We
//  sum every non-loopback interface. Runs only while a metrics view is on
//  screen (start/stop), to stay idle otherwise.
//

import Foundation
import Combine

@MainActor
final class NetworkMonitor: ObservableObject {
    /// Current download / upload throughput in MB/s (averaged over the last tick).
    @Published private(set) var rxMBs: Double = 0
    @Published private(set) var txMBs: Double = 0
    /// Recent total (rx+tx) MB/s, one sample per second — a ready-to-plot ring.
    @Published private(set) var history: [Double] = []

    private let interval: TimeInterval
    private let maxHistory: Int
    private var timer: Timer?

    private var lastRx: UInt64 = 0
    private var lastTx: UInt64 = 0
    private var lastAt: Date?

    /// `interval` defaults to 1 s — fine-grained enough to catch bursts without
    /// any subprocess cost. `window` is how many seconds of history to keep.
    init(interval: TimeInterval = 1.0, window: Int = 120) {
        self.interval = interval
        self.maxHistory = window
    }

    func start() {
        guard timer == nil else { return }
        // Seed the baseline so the first published rate is real, not a huge
        // delta-from-zero.
        let c = Self.counters()
        lastRx = c.rx; lastTx = c.tx; lastAt = Date()
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        t.tolerance = interval * 0.2
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        let now = Self.counters()
        let at = Date()
        defer { lastRx = now.rx; lastTx = now.tx; lastAt = at }
        guard let prev = lastAt else { return }
        let dt = at.timeIntervalSince(prev)
        guard dt > 0.05 else { return }
        // Skip a delta across a counter reset / 32-bit wrap.
        guard now.rx >= lastRx, now.tx >= lastTx else { return }
        let mb = 1_048_576.0
        rxMBs = Double(now.rx - lastRx) / mb / dt
        txMBs = Double(now.tx - lastTx) / mb / dt
        history.append(rxMBs + txMBs)
        if history.count > maxHistory { history.removeFirst(history.count - maxHistory) }
    }

    /// Sum of cumulative in/out bytes across every non-loopback interface.
    private static func counters() -> (rx: UInt64, tx: UInt64) {
        var rx: UInt64 = 0, tx: UInt64 = 0
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return (0, 0) }
        defer { freeifaddrs(head) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let p = ptr {
            let ifa = p.pointee
            ptr = ifa.ifa_next
            guard let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            let name = String(cString: ifa.ifa_name)
            if name.hasPrefix("lo") || name.hasPrefix("gif") || name.hasPrefix("stf") { continue }
            guard let raw = ifa.ifa_data else { continue }
            let data = raw.assumingMemoryBound(to: if_data.self).pointee
            rx += UInt64(data.ifi_ibytes)
            tx += UInt64(data.ifi_obytes)
        }
        return (rx, tx)
    }
}
