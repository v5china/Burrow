//
//  LocalizationTests.swift
//  BurrowTests
//

import XCTest
@testable import Burrow

final class LocalizationTests: XCTestCase {
    func testSimplifiedChineseStringsCoverCoreInterface() throws {
        let strings = try zhHansStrings()
        let requiredKeys = [
            "Clean",
            "Software",
            "Optimize",
            "Analyze",
            "Status",
            "Settings",
            "History",
            "Open Burrow",
            "Clean Now",
            "Preview",
            "Uninstall",
            "Updates",
            "Search apps",
            "Everything's up to date",
            "Update all",
            "Run maintenance now",
        ]

        for key in requiredKeys {
            let value = try XCTUnwrap(strings[key], "missing zh-Hans translation for \(key)")
            XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertNotEqual(value, key)
        }
    }

    private func zhHansStrings() throws -> [String: String] {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = sourceRoot
            .appendingPathComponent("Resources")
            .appendingPathComponent("zh-Hans.lproj")
            .appendingPathComponent("Localizable.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: String])
    }
}
