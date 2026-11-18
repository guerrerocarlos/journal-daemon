// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JournalDaemon",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "journal-daemon", targets: ["JournalDaemon"]),
    ],
    targets: [
        .executableTarget(name: "JournalDaemon"),
        .testTarget(name: "JournalDaemonTests", dependencies: ["JournalDaemon"]),
    ]
)
