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

    func testDJICaptureTimestampComesFromTheFilename() {
        XCTAssertEqual(Ingestor.captureTimestamp(for: URL(fileURLWithPath: "/Volumes/DJI/DJI_Audio_002/DJI_16_20261124_032817.WAV")), "20261124_032817")
        XCTAssertNil(Ingestor.captureTimestamp(for: URL(fileURLWithPath: "/Volumes/DJI/DJI_Audio_002/recording.WAV")))
    }

    func testAppleDoubleSidecarsAreRecognizedByTheirPrefix() {
        XCTAssertTrue(Ingestor.isAppleDoubleFile(URL(fileURLWithPath: "/Volumes/DJI/DJI_Audio_002/._DJI_16_20261124_032817.WAV")))
        XCTAssertFalse(Ingestor.isAppleDoubleFile(URL(fileURLWithPath: "/Volumes/DJI/DJI_Audio_002/DJI_16_20261124_032817.WAV")))
    }
}
