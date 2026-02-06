//
//  Database.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation
import GRDB

/// GRDB wrapper responsible for managing the app database lifecycle.
final class Database {
    let queue: DatabaseQueue

    /// Creates or opens the on-disk database and applies migrations.
    init(fileManager: FileManager = .default, bundle: Bundle = .main) throws {
        let folderURL = try Self.appSupportDirectory(using: fileManager)
        let databaseURL = folderURL.appendingPathComponent("Prism.sqlite")

        queue = try DatabaseQueue(path: databaseURL.path)
        try applyMigrations(using: bundle)
    }

    private func applyMigrations(using bundle: Bundle) throws {
        var migrator = DatabaseMigrator()
        let migrations = try MigrationLoader.loadMigrations(from: bundle)

        for migration in migrations {
            migrator.registerMigration(migration.id) { db in
                try db.execute(sql: migration.sql)
            }
        }

        try migrator.migrate(queue)
    }

    private static func appSupportDirectory(using fileManager: FileManager) throws -> URL {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let baseURL = urls.first else {
            throw CocoaError(.fileNoSuchFile)
        }

        let appFolder = baseURL.appendingPathComponent("Prism", isDirectory: true)
        if !fileManager.fileExists(atPath: appFolder.path) {
            try fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }

        return appFolder
    }
}
