//
//  MigrationLoader.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// Errors surfaced when migrations cannot be loaded.
enum MigrationLoaderError: Error {
    case noMigrationsFound
}

/// Loads SQL migrations embedded in the app bundle.
struct MigrationLoader {
    struct Migration: Identifiable {
        let id: String
        let sql: String
    }

    static func loadMigrations(from bundle: Bundle) throws -> [Migration] {
        let urls = bundle.urls(forResourcesWithExtension: "sql", subdirectory: nil) ?? []
        let migrations = urls
            .filter { $0.lastPathComponent.hasPrefix("Migration_") }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { url in
                let id = url.deletingPathExtension().lastPathComponent
                let sql = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                return Migration(id: id, sql: sql)
            }
            .filter { !$0.sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard !migrations.isEmpty else {
            throw MigrationLoaderError.noMigrationsFound
        }

        return migrations
    }
}
