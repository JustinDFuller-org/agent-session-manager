import XCTest

@testable import AgentSessionManager

final class FreePortAllocatorTests: XCTestCase {
    func testAllocateReturnsDistinctNonZeroPorts() {
        var ports = Set<Int>()
        for _ in 0..<8 {
            guard let port = FreePortAllocator.allocate() else {
                XCTFail("Expected a non-nil port")
                return
            }
            XCTAssertGreaterThan(port, 0, "Allocated port must be greater than zero")
            XCTAssertFalse(ports.contains(port), "Expected distinct ports, got duplicate \(port)")
            ports.insert(port)
        }
        XCTAssertEqual(ports.count, 8)
    }
}
