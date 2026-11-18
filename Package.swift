// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JournalDaemon",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "journal-daemon", targets: ["JournalDaemonCLI"]),
    ],
    targets: [
        .target(
            name: "JournalDaemonCore",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .executableTarget(name: "JournalDaemonCLI", dependencies: ["JournalDaemonCore"]),
        .testTarget(name: "JournalDaemonTests", dependencies: ["JournalDaemonCore"]),
    ]
)
