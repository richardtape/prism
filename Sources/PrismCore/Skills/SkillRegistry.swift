//
//  SkillRegistry.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation
import GRDB

/// Registry for tool-capable skills with enablement gating.
public final class SkillRegistry {
    private var skills: [String: Skill] = [:]
    private let queue: DatabaseQueue?
    private let permissionManager: PermissionManaging

    public init(queue: DatabaseQueue?, permissionManager: PermissionManaging = PermissionManager.shared) {
        self.queue = queue
        self.permissionManager = permissionManager
    }

    /// Registers a skill, replacing any existing entry for the same id.
    public func register(_ skill: Skill) {
        skills[skill.id] = skill
    }

    /// Returns all registered skills.
    public func allSkills() -> [Skill] {
        Array(skills.values)
    }

    /// Returns enabled skills by consulting SettingsStore.
    public func enabledSkills() -> [Skill] {
        guard let queue else { return [] }
        let store = SettingsStore(queue: queue)
        return skills.values.filter { skill in
            guard (try? store.readValue(for: Self.enabledKey(for: skill.id))) == "true" else {
                return false
            }

            guard let permission = SkillPermission(rawValue: skill.id) else {
                return true
            }

            return permissionManager.status(for: permission) == .authorized
        }
    }

    /// Returns tool schemas for enabled skills.
    public func enabledToolSchemas() -> [LLMToolDefinition] {
        enabledSkills().map { $0.toolSchema }
    }

    /// Resolves a skill by id.
    public func skill(id: String) -> Skill? {
        skills[id]
    }

    public static func enabledKey(for skillID: String) -> String {
        "skills.\(skillID).enabled"
    }
}
