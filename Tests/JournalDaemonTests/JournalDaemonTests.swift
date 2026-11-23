import XCTest
@testable import JournalDaemonCore

final class JournalDaemonTests: XCTestCase {
    func testBootstrapPackageLoads() {
        XCTAssertTrue(true)
    }

    func testTrashDirectoriesAreNeverEligible() {
        XCTAssertTrue(Ingestor.isTrashedPath(URL(fileURLWithPath: "/Volumes/DJI/.Trashes/501/DJI_01.WAV")))
        XCTAssertTrue(Ingestor.isTrashedPath(URL(fileURLWithPath: "/Volumes/DJI/$RECYCLE.BIN/DJI_01.WAV")))
        XCTAssertTrue(Ingestor.isTrashedPath(URL(fileURLWithPath: "/Volumes/DJI/DJI_Audio/Trash/DJI_01.WAV")))
        XCTAssertFalse(Ingestor.isTrashedPath(URL(fileURLWithPath: "/Volumes/DJI/DJI_Audio/DJI_01.WAV")))
    }
}
