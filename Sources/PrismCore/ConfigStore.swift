//
//  ConfigStore.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Configuration payload for the LLM connection.
public struct LLMConfig: Codable, Equatable, Sendable {
    public var endpoint: String
    public var apiKey: String
    public var model: String?

    public init(endpoint: String, apiKey: String, model: String? = nil) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.model = model
    }
}

/// File-backed store for configuration data outside of the database.
public final class ConfigStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Loads the config file, returning nil when no config exists yet.
    public func load() throws -> LLMConfig? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(LLMConfig.self, from: data)
    }

    /// Saves the config file, creating parent directories as needed.
    public func save(_ config: LLMConfig) throws {
        let data = try encoder.encode(config)
        let folder = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        try data.write(to: fileURL, options: [.atomic])
    }

    /// Deletes the config file if it exists.
    public func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    /// Default config location under Application Support.
    public static func defaultLocation(fileManager: FileManager = .default) throws -> URL {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let baseURL = urls.first else {
            throw CocoaError(.fileNoSuchFile)
        }
        let appFolder = baseURL.appendingPathComponent("Prism", isDirectory: true)
        let configFolder = appFolder.appendingPathComponent("Config", isDirectory: true)
        return configFolder.appendingPathComponent("llm-config.json")
    }
}
