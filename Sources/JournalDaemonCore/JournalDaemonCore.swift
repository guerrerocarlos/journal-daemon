import Foundation
import CryptoKit
import SQLite3
import Security

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum DaemonError: LocalizedError {
    case message(String)
    public var errorDescription: String? {
        if case let .message(value) = self { return value }
        return nil
    }
}

public struct Configuration: Codable {
    public struct Volume: Codable { public let nameRegex: String; public let volumeUUID: String?; public let requireRemovable: Bool }
    public struct Source: Codable { public let id: String; public let volume: Volume; public let roots: [String]; public let includeExtensions: [String]; public let excludeNameRegex: String?; public let stableForSeconds: Int }
    public struct Auth: Codable { public let type: String; public let service: String; public let account: String }
    public struct Destination: Codable { public let baseURL: String; public let importPath: String; public let auth: Auth; public let requestTimeoutSeconds: Int }
    public struct Spool: Codable { public let directory: String; public let maximumBytes: Int64 }
    public struct Behavior: Codable { public let scanMountedVolumesAtStartup: Bool; public let uploadConcurrency: Int; public let deleteSourceAfterUpload: Bool; public let keepSpoolAfterUpload: Bool }
    public struct Logging: Codable { public let level: String; public let directory: String }
    public let version: Int; public let sources: [Source]; public let destination: Destination; public let spool: Spool; public let behavior: Behavior; public let logging: Logging

    public static func load(path: String) throws -> Configuration {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(Configuration.self, from: data)
        guard config.version == 1, !config.sources.isEmpty else { throw DaemonError.message("Configuration requires version 1 and at least one source.") }
        guard config.behavior.deleteSourceAfterUpload == false else { throw DaemonError.message("deleteSourceAfterUpload must remain false.") }
        guard URL(string: config.destination.baseURL)?.scheme == "https" else { throw DaemonError.message("destination.baseURL must use HTTPS.") }
        guard config.destination.auth.type == "keychain" else { throw DaemonError.message("Only Keychain authentication is supported.") }
        for source in config.sources {
            guard source.id.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil,
                  source.stableForSeconds >= 0,
                  !source.roots.contains(where: { $0.hasPrefix("/") || $0.split(separator: "/").contains("..") }) else { throw DaemonError.message("Invalid source \(source.id).") }
            _ = try NSRegularExpression(pattern: source.volume.nameRegex)
            if let expression = source.excludeNameRegex { _ = try NSRegularExpression(pattern: expression) }
        }
        return config
    }
    public func expandedSpoolDirectory() -> URL {
        URL(fileURLWithPath: (spool.directory as NSString).expandingTildeInPath, isDirectory: true)
    }
}

public final class StateStore {
    private var db: OpaquePointer?
    public init(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("state.sqlite").path
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else { throw DaemonError.message("Cannot open state database.") }
        try execute("PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; CREATE TABLE IF NOT EXISTS files (digest TEXT PRIMARY KEY, source_id TEXT NOT NULL, original_path TEXT NOT NULL, spool_path TEXT NOT NULL, bytes INTEGER NOT NULL, status TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, next_attempt REAL NOT NULL DEFAULT 0, last_error TEXT, import_id TEXT, created_at REAL NOT NULL, acknowledged_at REAL);")
    }
    deinit { sqlite3_close(db) }
    private func execute(_ sql: String) throws { guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw DaemonError.message("SQLite error: \(String(cString: sqlite3_errmsg(db)))") } }
    private func query(_ sql: String, _ bind: (OpaquePointer?) -> Void = { _ in }) throws -> [[String: String]] {
        var statement: OpaquePointer?; guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw DaemonError.message("SQLite query error.") }; defer { sqlite3_finalize(statement) }; bind(statement)
        var rows: [[String: String]] = []; while sqlite3_step(statement) == SQLITE_ROW { var row: [String: String] = [:]; for index in 0..<sqlite3_column_count(statement) { row[String(cString: sqlite3_column_name(statement, index))] = sqlite3_column_text(statement, index).map { String(cString: $0) } ?? "" }; rows.append(row) }; return rows
    }
    public func hasDigest(_ digest: String) throws -> Bool { try !query("SELECT digest FROM files WHERE digest=? LIMIT 1") { sqlite3_bind_text($0, 1, digest, -1, SQLITE_TRANSIENT) }.isEmpty }
    public func insert(digest: String, source: String, original: String, spool: String, bytes: Int64) throws {
        var statement: OpaquePointer?; let sql = "INSERT OR IGNORE INTO files (digest,source_id,original_path,spool_path,bytes,status,created_at) VALUES (?,?,?,?,?,'pending',?)"; guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw DaemonError.message("SQLite insert error.") }; defer { sqlite3_finalize(statement) }
        [digest, source, original, spool].enumerated().forEach { sqlite3_bind_text(statement, Int32($0.offset + 1), $0.element, -1, SQLITE_TRANSIENT) }; sqlite3_bind_int64(statement, 5, bytes); sqlite3_bind_double(statement, 6, Date().timeIntervalSince1970); guard sqlite3_step(statement) == SQLITE_DONE else { throw DaemonError.message("SQLite insert failed.") }
    }
    public func pending() throws -> [[String: String]] { try query("SELECT digest,source_id,original_path,spool_path,bytes,attempts FROM files WHERE status='pending' AND next_attempt <= strftime('%s','now') ORDER BY created_at LIMIT 20") }
    public func acknowledge(_ digest: String, importID: String?) throws { try execute("UPDATE files SET status='acknowledged', import_id=\(sql(importID ?? "")), acknowledged_at=strftime('%s','now'), last_error=NULL WHERE digest=\(sql(digest));") }
    public func fail(_ digest: String, error: String) throws { try execute("UPDATE files SET attempts=attempts+1, next_attempt=strftime('%s','now') + MIN(3600, (1 << MIN(10,attempts+1)) * 5), last_error=\(sql(String(error.prefix(500))) WHERE digest=\(sql(digest));") }
    public func retryAll() throws { try execute("UPDATE files SET next_attempt=0, status='pending' WHERE status != 'acknowledged';") }
    public func summary() throws -> [String: Int] { var result: [String: Int] = [:]; for row in try query("SELECT status, COUNT(*) AS count FROM files GROUP BY status") { result[row["status"] ?? "unknown"] = Int(row["count"] ?? "0") ?? 0 }; return result }
    private func sql(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "''") + "'" }
}

public final class Ingestor {
    private let config: Configuration; private let store: StateStore; private let spool: URL
    public init(config: Configuration) throws { self.config = config; spool = config.expandedSpoolDirectory(); store = try StateStore(directory: spool) }
    public func scan(dryRun: Bool) throws -> Int {
        let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey, .volumeUUIDStringKey, .volumeIsRemovableKey], options: [.skipHiddenVolumes]) ?? []
        var found = 0
        for volume in volumes { for source in config.sources where matches(volume: volume, source: source) { for root in source.roots { found += try ingest(root: volume.appendingPathComponent(root), volume: volume, source: source, dryRun: dryRun) } } }
        return found
    }
    private func matches(volume: URL, source: Configuration.Source) -> Bool {
        let values = try? volume.resourceValues(forKeys: [.volumeNameKey, .volumeUUIDStringKey, .volumeIsRemovableKey]); let name = values?.volumeName ?? ""
        guard name.range(of: source.volume.nameRegex, options: .regularExpression) != nil else { return false }
        if let uuid = source.volume.volumeUUID, values?.volumeUUIDString != uuid { return false }; if source.volume.requireRemovable, values?.volumeIsRemovable != true { return false }; return true
    }
    private func ingest(root: URL, volume: URL, source: Configuration.Source, dryRun: Bool) throws -> Int {
        guard let iterator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else { return 0 }; var count = 0
        while let file = iterator.nextObject() as? URL {
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]); guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            let extensionAllowed = source.includeExtensions.contains(file.pathExtension.lowercased()); let excluded = source.excludeNameRegex.map { file.lastPathComponent.range(of: $0, options: .regularExpression) != nil } ?? false
            guard extensionAllowed, !excluded, Date().timeIntervalSince(values.contentModificationDate ?? Date()) >= Double(source.stableForSeconds) else { continue }
            let relative = file.path.replacingOccurrences(of: volume.path + "/", with: ""); if dryRun { print("Would spool \(relative)"); count += 1; continue }
            if try copy(file: file, sourceID: source.id, original: relative) { count += 1 }
        }; return count
    }
    private func copy(file: URL, sourceID: String, original: String) throws -> Bool {
        let temporary = spool.appendingPathComponent(".copy-\(UUID().uuidString)"); FileManager.default.createFile(atPath: temporary.path, contents: nil); let input = try FileHandle(forReadingFrom: file); let output = try FileHandle(forWritingTo: temporary); defer { try? input.close(); try? output.close() }
        var hash = SHA256(); var bytes: Int64 = 0; while true { let data = try input.read(upToCount: 1_048_576) ?? Data(); if data.isEmpty { break }; hash.update(data: data); try output.write(contentsOf: data); bytes += Int64(data.count) }; try output.synchronize(); let digest = hash.finalize().map { String(format: "%02x", $0) }.joined(); if try store.hasDigest(digest) { try? FileManager.default.removeItem(at: temporary); return false }
        let destination = spool.appendingPathComponent(digest + "-" + file.lastPathComponent); try FileManager.default.moveItem(at: temporary, to: destination); try store.insert(digest: digest, source: sourceID, original: original, spool: destination.path, bytes: bytes); return true
    }
    public func uploadPending() throws -> Int { let token = try Keychain.token(service: config.destination.auth.service, account: config.destination.auth.account); var uploaded = 0; for record in try store.pending() { do { let id = try Uploader.upload(record: record, config: config, token: token); try store.acknowledge(record["digest"]!, importID: id); if !config.behavior.keepSpoolAfterUpload { try? FileManager.default.removeItem(atPath: record["spool_path"]!) }; uploaded += 1 } catch { try store.fail(record["digest"]!, error: error.localizedDescription) } }; return uploaded }
    public func status() throws -> [String: Int] { try store.summary() }
    public func retryAll() throws { try store.retryAll() }
}

enum Keychain { static func token(service: String, account: String) throws -> String { var item: CFTypeRef?; let status = SecItemCopyMatching([kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account, kSecReturnData: true] as CFDictionary, &item); guard status == errSecSuccess, let data = item as? Data, let value = String(data: data, encoding: .utf8) else { throw DaemonError.message("No Keychain token found. Run journal-daemon auth set-token.") }; return value } }

enum Uploader {
    static func upload(record: [String: String], config: Configuration, token: String) throws -> String? {
        guard let url = URL(string: config.destination.importPath, relativeTo: URL(string: config.destination.baseURL)), let file = record["spool_path"], let digest = record["digest"] else { throw DaemonError.message("Invalid upload configuration.") }; let boundary = "JournalDaemon-\(UUID().uuidString)"; let body = URL(fileURLWithPath: file + ".upload"); defer { try? FileManager.default.removeItem(at: body) }; var data = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"metadata\"\r\nContent-Type: application/json\r\n\r\n".utf8); let metadata: [String: Any] = ["version": 1, "sourceId": record["source_id"] ?? "", "originalPath": record["original_path"] ?? "", "sha256": digest, "byteCount": Int64(record["bytes"] ?? "0") ?? 0]; data.append(try JSONSerialization.data(withJSONObject: metadata)); data.append(Data("\r\n--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(URL(fileURLWithPath: file).lastPathComponent)\"\r\nContent-Type: application/octet-stream\r\n\r\n".utf8)); try data.write(to: body); let output = try FileHandle(forWritingTo: body); let input = try FileHandle(forReadingFrom: URL(fileURLWithPath: file)); while let chunk = try input.read(upToCount: 1_048_576), !chunk.isEmpty { try output.write(contentsOf: chunk) }; try output.write(contentsOf: Data("\r\n--\(boundary)--\r\n".utf8)); try input.close(); try output.close()
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = TimeInterval(config.destination.requestTimeoutSeconds); request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization"); request.setValue("sha256:\(digest)", forHTTPHeaderField: "Idempotency-Key"); request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type"); let semaphore = DispatchSemaphore(value: 0); var responseData = Data(); var response: URLResponse?; var failure: Error?; URLSession.shared.uploadTask(with: request, fromFile: body) { data, result, error in responseData = data ?? Data(); response = result; failure = error; semaphore.signal() }.resume(); semaphore.wait(); if let failure { throw failure }; let code = (response as? HTTPURLResponse)?.statusCode ?? 0; guard (200...201).contains(code) || code == 409 else { throw DaemonError.message("Upload returned HTTP \(code).") }; let object = (try? JSONSerialization.jsonObject(with: responseData)) as? [String: Any]; guard object?["sha256"] as? String == digest else { throw DaemonError.message("Upload response digest mismatch.") }; return object?["importId"] as? String
    }
}
