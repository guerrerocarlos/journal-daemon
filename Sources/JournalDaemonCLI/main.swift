import Foundation
import JournalDaemonCore

let version = "0.2.0-dev"
func usage() { print("Usage: journal-daemon <version|doctor|run|status|scan|retry|config validate|bell ...>") }
func configPath(_ args: [String]) -> String { if let i = args.firstIndex(of: "--config"), args.indices.contains(i + 1) { return args[i + 1] }; return "~/.config/journal-daemon/config.json" }
func run(_ config: Configuration) throws { let ingestor = try Ingestor(config: config); while true { _ = try ingestor.scan(dryRun: false); _ = try ingestor.uploadPending(); Thread.sleep(forTimeInterval: 15) } }
let args = Array(CommandLine.arguments.dropFirst()); do {
    switch args {
    case ["version"]: print("journal-daemon \(version)")
    case let value where value.count == 4 && Array(value[0...2]) == ["config", "validate", "--config"]: _ = try Configuration.load(path: value[3]); print("Configuration is valid: \(value[3])")
    case let value where value.first == "scan": let config = try Configuration.load(path: configPath(value)); let count = try Ingestor(config: config).scan(dryRun: value.contains("--dry-run")); print("Discovered \(count) eligible file(s).")
    case let value where value.first == "status": let config = try Configuration.load(path: configPath(value)); let summary = try Ingestor(config: config).status(); print(summary.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "\n"))
    case let value where value.first == "retry": let config = try Configuration.load(path: configPath(value)); try Ingestor(config: config).retryAll(); print("Pending uploads scheduled for retry.")
    case let value where value.first == "run": try run(try Configuration.load(path: configPath(value)))
    case ["doctor"]: print("journal-daemon \(version)\nUse config validate, scan, status, and run with a configured macOS host.")
    default: usage(); exit(64)
    }
} catch { FileHandle.standardError.write(Data("journal-daemon: \(error.localizedDescription)\n".utf8)); exit(1) }
