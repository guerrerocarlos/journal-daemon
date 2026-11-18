import Foundation

private let version = "0.1.0-dev"

private enum ExitCode: Int32 {
    case success = 0
    case usage = 64
    case configuration = 78
    case unavailable = 69
}

private let bellSounds = [
    "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse",
    "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
]

private func usage() {
    print("""
    Usage:
      journal-daemon version
      journal-daemon config validate --config PATH
      journal-daemon doctor
      journal-daemon bell sounds
      journal-daemon bell ring [--sound SOUND]
      journal-daemon bell send --device TAILNET_DEVICE [--user SSH_USER] [--sound SOUND]

    This bootstrap build validates configuration and installation prerequisites.
    Bell commands use local macOS sounds and SSH over Tailscale. Device ingestion,
    background service operation, and API upload are not yet implemented.
    """)
}

private func validateConfiguration(at path: String) throws {
    let url = URL(fileURLWithPath: path).standardizedFileURL
    let data = try Data(contentsOf: url)
    guard let document = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw ValidationError("The configuration root must be a JSON object.")
    }
    guard (document["version"] as? NSNumber)?.intValue == 1 else {
        throw ValidationError("Expected configuration version 1.")
    }
    guard let sources = document["sources"] as? [[String: Any]], !sources.isEmpty else {
        throw ValidationError("Expected at least one configured source.")
    }
    guard document["destination"] as? [String: Any] != nil else {
        throw ValidationError("Expected a destination object.")
    }
    guard document["spool"] as? [String: Any] != nil else {
        throw ValidationError("Expected a spool object.")
    }
    print("Configuration is valid: \(url.path)")
}

private struct ValidationError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

private struct BellError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

private func selectedBellSound(_ requestedSound: String?) throws -> String {
    let sound = requestedSound ?? "Glass"
    guard bellSounds.contains(sound) else {
        throw BellError("Unknown sound '\(sound)'. Run 'journal-daemon bell sounds' for the allowed names.")
    }
    return sound
}

private func validatedTailnetDevice(_ device: String) throws -> String {
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_")
    guard !device.isEmpty,
          device.count <= 253,
          !device.hasPrefix("-"),
          device.rangeOfCharacter(from: allowed.inverted) == nil else {
        throw BellError("Invalid Tailscale device name '\(device)'.")
    }
    return device
}

private func validatedSSHUser(_ user: String) throws -> String {
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
    guard !user.isEmpty,
          user.count <= 64,
          !user.hasPrefix("-"),
          user.rangeOfCharacter(from: allowed.inverted) == nil else {
        throw BellError("Invalid SSH user '\(user)'.")
    }
    return user
}

@discardableResult
private func runProcess(executable: String, arguments: [String]) throws -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
}

private func ringBell(sound: String) throws {
    let file = "/System/Library/Sounds/\(sound).aiff"
    guard FileManager.default.isReadableFile(atPath: file) else {
        throw BellError("The macOS sound file is unavailable: \(file)")
    }
    let status = try runProcess(executable: "/usr/bin/afplay", arguments: [file])
    guard status == 0 else {
        throw BellError("afplay exited with status \(status).")
    }
    print("Rang \(sound).")
}

private func sendBell(device: String, user: String, sound: String) throws {
    let status = try runProcess(
        executable: "/usr/bin/ssh",
        arguments: ["-o", "BatchMode=yes", "\(user)@\(device)", "journal-daemon", "bell", "ring", "--sound", sound]
    )
    guard status == 0 else {
        throw BellError("SSH to \(user)@\(device) exited with status \(status). Check Tailscale connectivity, the SSH key and known-host entry, and that journal-daemon is installed on the destination.")
    }
    print("Requested \(sound) on \(user)@\(device).")
}

private func parseBellSendOptions(_ arguments: [String]) throws -> (device: String, user: String, sound: String) {
    var device: String?
    var user: String?
    var sound: String?
    var index = 2
    while index < arguments.count {
        guard index + 1 < arguments.count else {
            throw BellError("Missing value for '\(arguments[index])'.")
        }
        let option = arguments[index]
        let value = arguments[index + 1]
        switch option {
        case "--device" where device == nil:
            device = value
        case "--user" where user == nil:
            user = value
        case "--sound" where sound == nil:
            sound = value
        default:
            throw BellError("Invalid or repeated bell send option '\(option)'.")
        }
        index += 2
    }
    guard let device else {
        throw BellError("Bell send requires --device TAILNET_DEVICE.")
    }
    return (
        device: try validatedTailnetDevice(device),
        user: try validatedSSHUser(user ?? NSUserName()),
        sound: try selectedBellSound(sound)
    )
}

private func handleBell(_ arguments: [String]) throws {
    if arguments == ["bell", "sounds"] {
        print(bellSounds.joined(separator: "\n"))
    } else if arguments == ["bell", "ring"] {
        try ringBell(sound: selectedBellSound(nil))
    } else if arguments.count == 4,
              Array(arguments[0...2]) == ["bell", "ring", "--sound"] {
        try ringBell(sound: selectedBellSound(arguments[3]))
    } else if arguments.count >= 4,
              Array(arguments[0...1]) == ["bell", "send"] {
        let options = try parseBellSendOptions(arguments)
        try sendBell(device: options.device, user: options.user, sound: options.sound)
    } else {
        throw BellError("Invalid bell command. Run 'journal-daemon' for usage.")
    }
}

private let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments {
case ["version"]:
    print("journal-daemon \(version)")
case ["doctor"]:
    print("journal-daemon \(version)")
    print("Bootstrap installation is healthy.")
    print("Bell sound bridging is available through SSH over Tailscale.")
    print("Device ingestion and upload support are not implemented in this build.")
case let configurationArguments where configurationArguments.count == 4 &&
    Array(configurationArguments[0...2]) == ["config", "validate", "--config"]:
    do {
        try validateConfiguration(at: configurationArguments[3])
    } catch {
        FileHandle.standardError.write(Data("Configuration validation failed: \(error.localizedDescription)\n".utf8))
        exit(ExitCode.configuration.rawValue)
    }
case let bellArguments where bellArguments.first == "bell":
    do {
        try handleBell(bellArguments)
    } catch {
        FileHandle.standardError.write(Data("Bell command failed: \(error.localizedDescription)\n".utf8))
        exit(ExitCode.unavailable.rawValue)
    }
default:
    usage()
    exit(ExitCode.usage.rawValue)
}
