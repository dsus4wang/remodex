// FILE: SubscriptionServiceAccessTests.swift
// Purpose: Verifies forced-Pro access keeps app access unlocked.
// Layer: Unit Test
// Exports: SubscriptionServiceAccessTests
// Depends on: XCTest, CodexMobile

import XCTest
@testable import CodexMobile

@MainActor
final class SubscriptionServiceAccessTests: XCTestCase {
    func testServiceStartsWithProAccess() {
        let service = makeService()

        XCTAssertTrue(service.hasProAccess)
        XCTAssertTrue(service.hasAppAccess)
    }

    func testFreeSendAttemptsAreNotConsumedWhenProIsForced() {
        let service = makeService()

        for _ in 0..<7 {
            service.consumeFreeSendAttemptIfNeeded()
        }

        XCTAssertTrue(service.hasProAccess)
        XCTAssertTrue(service.hasAppAccess)
    }

    private func makeService() -> SubscriptionService {
        let suiteName = "SubscriptionServiceAccessTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return SubscriptionService(defaults: defaults)
    }
}
