import Foundation
import Dispatch
import JournalDaemonCore

let version = "0.2.0-dev"
let sounds = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]
func usage() { print("Usage: journal-daemon <version|doctor|run|status|scan|retry|config validate|auth set-token|auth test|bell>") }
func configPath(_ args: [String]) -> String { if let i = args.firstIndex(of: "--config"), args.indices.contains(i + 1) { return args[i + 1] }; return "~/.config/journal-daemon/config.json" }
func config(_ args: [String]) throws -> Configuration { try Configuration.load(path: configPath(args)) }
func run(_ configuration: Configuration) throws { let ingestor = try Ingestor(config: configuration); signal(SIGTERM, SIG_IGN); let stop = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main); stop.setEventHandler { exit(0) }; stop.resume(); while true { _ = try ingestor.scan(dryRun: false); _ = try? ingestor.uploadPending(); Thread.sleep(forTimeInterval: 15) } }
func ring(_ sound: String) throws { guard sounds.contains(sound) else { throw DaemonError.message("Unknown sound \(sound).") }; let path = "/System/Library/Sounds/\(sound).aiff"; guard FileManager.default.isReadableFile(atPath: path) else { throw DaemonError.message("Sound unavailable: \(path)") }; let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay"); process.arguments = [path]; try process.run(); process.waitUntilExit(); guard process.terminationStatus == 0 else { throw DaemonError.message("afplay failed.") }; print("Rang \(sound).") }
func sendBell(_ args: [String]) throws { guard let deviceIndex = args.firstIndex(of: "--device"), args.indices.contains(deviceIndex + 1) else { throw DaemonError.message("bell send requires --device NAME.") }; let user = args.firstIndex(of: "--user").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? NSUserName(); let sound = args.firstIndex(of: "--sound").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? "Glass"; guard args[deviceIndex + 1].range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil, user.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else { throw DaemonError.message("Invalid bell destination.") }; let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh"); process.arguments = ["-o", "BatchMode=yes", "\(user)@\(args[deviceIndex + 1])", "journal-daemon", "bell", "ring", "--sound", sound]; try process.run(); process.waitUntilExit(); guard process.terminationStatus == 0 else { throw DaemonError.message("Remote bell SSH request failed.") } }
func setToken(_ configuration: Configuration) throws { FileHandle.standardOutput.write(Data("Token: ".utf8)); let token = readLine(strippingNewline: true) ?? ""; guard !token.isEmpty else { throw DaemonError.message("Empty token.") }; try Keychain.set(token, service: configuration.destination.auth.service, account: configuration.destination.auth.account); print("Stored token in Keychain.") }
let args = Array(CommandLine.arguments.dropFirst()); do {
    if args == ["version"] { print("journal-daemon \(version)") }
    else if args.count == 4 && Array(args[0...2]) == ["config", "validate", "--config"] { _ = try Configuration.load(path: args[3]); print("Configuration is valid: \(args[3])") }
    else if args.first == "scan" { let ingest = try Ingestor(config: config(args)); print("Discovered \(try ingest.scan(dryRun: args.contains("--dry-run"))) eligible file(s).") }
    else if args.first == "status" { let summary = try Ingestor(config: config(args)).status(); print(summary.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "\n")) }
    else if args.first == "retry" { try Ingestor(config: config(args)).retryAll(); print("Pending uploads scheduled for retry.") }
    else if args.first == "run" { try run(config(args)) }
    else if args == ["auth", "test"] { let c = try config(args); try Keychain.token(service: c.destination.auth.service, account: c.destination.auth.account); print("Keychain token is available.") }
    else if args == ["auth", "set-token"] { try setToken(config(args)) }
    else if args == ["bell", "sounds"] { print(sounds.joined(separator: "\n")) }
    else if args == ["bell", "ring"] { try ring("Glass") }
    else if args.count == 4 && Array(args[0...2]) == ["bell", "ring", "--sound"] { try ring(args[3]) }
    else if args.count >= 4 && Array(args[0...1]) == ["bell", "send"] { try sendBell(args) }
    else if args == ["doctor"] { print("journal-daemon \(version)\nUse config validate, scan, status, and run with a configured macOS host.") }
    else { usage(); exit(64) }
} catch { FileHandle.standardError.write(Data("journal-daemon: \(error.localizedDescription)\n".utf8)); exit(1) }
