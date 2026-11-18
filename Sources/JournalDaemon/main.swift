import Foundation

private let version = "0.1.0-dev"

private enum ExitCode: Int32 {
    case success = 0
    case usage = 64
    case configuration = 78
}

private func usage() {
    print("""
    Usage:
      journal-daemon version
      journal-daemon config validate --config PATH
      journal-daemon doctor

    This bootstrap build validates configuration and installation prerequisites.
    Device ingestion, background service operation, and API upload are not yet implemented.
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

private let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments {
case ["version"]:
    print("journal-daemon \(version)")
case ["doctor"]:
    print("journal-daemon \(version)")
    print("Bootstrap installation is healthy.")
    print("Device ingestion and upload support are not implemented in this build.")
case ["config", "validate", "--config", let path]:
    do {
        try validateConfiguration(at: path)
    } catch {
        FileHandle.standardError.write(Data("Configuration validation failed: \(error.localizedDescription)\n".utf8))
        exit(ExitCode.configuration.rawValue)
    }
default:
    usage()
    exit(ExitCode.usage.rawValue)
}
