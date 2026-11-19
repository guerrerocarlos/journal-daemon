import Foundation
import Dispatch
import Darwin
import AppKit
import JournalDaemonCore

let version = "0.2.0-dev"
let sounds = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]
func usage() { print("Usage: journal-daemon <version|doctor|run|status|scan|retry|config validate|auth set-token|auth test|bell>") }
func configPath(_ args: [String]) -> String { if let i = args.firstIndex(of: "--config"), args.indices.contains(i + 1) { return args[i + 1] }; return "~/.config/journal-daemon/config.json" }
func config(_ args: [String]) throws -> Configuration { try Configuration.load(path: configPath(args)) }
final class MenuBarStatus: NSObject {
    private let ingestor: Ingestor
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    init(ingestor: Ingestor) { self.ingestor = ingestor; super.init(); item.isVisible = false; item.menu = NSMenu() }
    func refresh() {
        let connected = ingestor.connectedSources()
        item.isVisible = !connected.isEmpty
        guard !connected.isEmpty else { return }
        let names = connected.map { "\($0.volumeName) (\($0.id))" }
        item.button?.image = NSImage(systemSymbolName: "externaldrive.connected.to.line.below", accessibilityDescription: "Journal Daemon device connected")
        item.button?.toolTip = "Journal Daemon: \(names.joined(separator: ", ")) connected"
        let menu = NSMenu()
        let status = NSMenuItem(title: "Connected: \(names.joined(separator: ", "))", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())
        let rescan = NSMenuItem(title: "Scan now", action: #selector(scanNow), keyEquivalent: "r")
        rescan.target = self
        menu.addItem(rescan)
        item.menu = menu
    }
    @objc private func scanNow() { _ = try? ingestor.scan(dryRun: false); _ = try? ingestor.uploadPending(); refresh() }
}
func run(_ configuration: Configuration) throws {
    let ingestor = try Ingestor(config: configuration)
    NSApplication.shared.setActivationPolicy(.accessory)
    let menuBar = MenuBarStatus(ingestor: ingestor)
    func tick() { _ = try? ingestor.scan(dryRun: false); _ = try? ingestor.uploadPending(); menuBar.refresh() }
    tick()
    Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in tick() }
    signal(SIGTERM, SIG_IGN)
    let stop = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    stop.setEventHandler { exit(0) }
    stop.resume()
    RunLoop.main.run()
}
func ring(_ sound: String) throws { guard sounds.contains(sound) else { throw DaemonError.message("Unknown sound \(sound).") }; let path = "/System/Library/Sounds/\(sound).aiff"; guard FileManager.default.isReadableFile(atPath: path) else { throw DaemonError.message("Sound unavailable: \(path)") }; let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay"); process.arguments = [path]; try process.run(); process.waitUntilExit(); guard process.terminationStatus == 0 else { throw DaemonError.message("afplay failed.") }; print("Rang \(sound).") }
func sendBell(_ args: [String]) throws { guard let deviceIndex = args.firstIndex(of: "--device"), args.indices.contains(deviceIndex + 1) else { throw DaemonError.message("bell send requires --device NAME.") }; let user = args.firstIndex(of: "--user").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? NSUserName(); let sound = args.firstIndex(of: "--sound").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? "Glass"; guard args[deviceIndex + 1].range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil, user.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else { throw DaemonError.message("Invalid bell destination.") }; let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh"); process.arguments = ["-o", "BatchMode=yes", "\(user)@\(args[deviceIndex + 1])", "journal-daemon", "bell", "ring", "--sound", sound]; try process.run(); process.waitUntilExit(); guard process.terminationStatus == 0 else { throw DaemonError.message("Remote bell SSH request failed.") } }
func setToken(_ configuration: Configuration) throws {
    guard isatty(STDIN_FILENO) == 1 else { throw DaemonError.message("auth set-token requires an interactive terminal.") }
    func stty(_ arguments: [String]) { let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/stty"); process.arguments = arguments; try? process.run(); process.waitUntilExit() }
    FileHandle.standardOutput.write(Data("Token: ".utf8)); stty(["-echo"]); defer { stty(["echo"]); print("") }
    let token = readLine(strippingNewline: true) ?? ""; guard !token.isEmpty else { throw DaemonError.message("Empty token.") }
    try Keychain.set(token, service: configuration.destination.auth.service, account: configuration.destination.auth.account); print("Stored token in Keychain.")
}
let args = Array(CommandLine.arguments.dropFirst()); do {
    if args == ["version"] { print("journal-daemon \(version)") }
    else if args.count == 4 && Array(args[0...2]) == ["config", "validate", "--config"] { _ = try Configuration.load(path: args[3]); print("Configuration is valid: \(args[3])") }
    else if args.first == "scan" { let ingest = try Ingestor(config: config(args)); print("Discovered \(try ingest.scan(dryRun: args.contains("--dry-run"))) eligible file(s).") }
    else if args.first == "status" { let summary = try Ingestor(config: config(args)).status(); print(summary.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "\n")) }
    else if args.first == "retry" { try Ingestor(config: config(args)).retryAll(); print("Pending uploads scheduled for retry.") }
    else if args.first == "run" { try run(config(args)) }
    else if args.count >= 2 && Array(args[0...1]) == ["auth", "test"] { let c = try config(args); try Keychain.token(service: c.destination.auth.service, account: c.destination.auth.account); print("Keychain token is available.") }
    else if args.count >= 2 && Array(args[0...1]) == ["auth", "set-token"] { try setToken(config(args)) }
    else if args == ["bell", "sounds"] { print(sounds.joined(separator: "\n")) }
    else if args == ["bell", "ring"] { try ring("Glass") }
    else if args.count == 4 && Array(args[0...2]) == ["bell", "ring", "--sound"] { try ring(args[3]) }
    else if args.count >= 4 && Array(args[0...1]) == ["bell", "send"] { try sendBell(args) }
    else if args == ["doctor"] { print("journal-daemon \(version)\nUse config validate, scan, status, and run with a configured macOS host.") }
    else { usage(); exit(64) }
} catch { FileHandle.standardError.write(Data("journal-daemon: \(error.localizedDescription)\n".utf8)); exit(1) }
