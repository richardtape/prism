//
//  RemindersSkill.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-08.
//

import EventKit
import Foundation

/// EventKit-backed skill for managing reminders in named lists.
public struct RemindersSkill: Skill, @unchecked Sendable {
    public let id: String = "reminders"
    public let metadata = SkillMetadata(
        name: "Reminders",
        description: "Create, update, complete, and list reminders in a specific list."
    )

    public let toolSchema: LLMToolDefinition = LLMToolDefinition(function: .init(
        name: "reminders",
        description: "Manage reminders within a specific list.",
        parameters: .object([
            "type": .string("object"),
            "properties": .object([
                "action": .object([
                    "type": .string("string"),
                    "enum": .array([
                        .string("create"),
                        .string("update"),
                        .string("remove"),
                        .string("list"),
                        .string("complete")
                    ])
                ]),
                "list": .object([
                    "type": .string("string"),
                    "description": .string("Reminders list name (required).")
                ]),
                "title": .object([
                    "type": .string("string"),
                    "description": .string("Reminder title (required for create/update/remove/complete).")
                ]),
                "newTitle": .object([
                    "type": .string("string"),
                    "description": .string("New title to apply when updating a reminder.")
                ])
            ]),
            "required": .array([
                .string("action"),
                .string("list")
            ])
        ])
    ))

    // EventKit is not Sendable; this store is used only within the async execution path.
    private let eventStore: EKEventStore

    public init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    public func execute(call: ToolCall) async throws -> SkillResult {
        let args = ToolArguments(arguments: call.arguments)
        let action = args.string("action") ?? ""
        let listName = args.string("list")
        let title = args.string("title")
        let newTitle = args.string("newTitle")

        guard let listName, !listName.isEmpty else {
            return clarificationOutput("Which reminders list should I use?")
        }

        switch action {
        case "list":
            return await listReminders(in: listName)
        case "create":
            guard let title, !title.isEmpty else {
                return clarificationOutput("What reminder should I add to \(listName)?")
            }
            return await createReminder(title: title, listName: listName)
        case "update":
            guard let title, !title.isEmpty else {
                return clarificationOutput("Which reminder in \(listName) should I update?")
            }
            guard let newTitle, !newTitle.isEmpty else {
                return clarificationOutput("What should I update that reminder to?")
            }
            return await updateReminder(title: title, newTitle: newTitle, listName: listName)
        case "remove":
            guard let title, !title.isEmpty else {
                return clarificationOutput("Which reminder in \(listName) should I remove?")
            }
            return await removeReminder(title: title, listName: listName)
        case "complete":
            guard let title, !title.isEmpty else {
                return clarificationOutput("Which reminder in \(listName) should I mark complete?")
            }
            return await completeReminder(title: title, listName: listName)
        default:
            return errorOutput("Unsupported reminders action.")
        }
    }

    private func listReminders(in listName: String) async -> SkillResult {
        guard let calendar = findCalendar(named: listName) else {
            return errorOutput("I couldn't find a reminders list named \(listName).")
        }

        let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: [calendar])
        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let sorted = (reminders ?? [])
                    .sorted { ($0.dueDateComponents?.date ?? .distantFuture) < ($1.dueDateComponents?.date ?? .distantFuture) }

                if sorted.isEmpty {
                    continuation.resume(returning: okOutput("No incomplete reminders in \(listName).", data: .array([])))
                    return
                }

                let titles = sorted.map { $0.title ?? "(Untitled)" }
                let preview = titles.prefix(5).joined(separator: ", ")
                let summarySuffix = titles.count > 5 ? " and \(titles.count - 5) more" : ""
                let summary = "Found \(titles.count) reminders in \(listName): \(preview)\(summarySuffix)."
                let payload = sorted.map { reminder in
                    JSONValue.object([
                        "title": .string(reminder.title ?? ""),
                        "isCompleted": .bool(reminder.isCompleted)
                    ])
                }

                continuation.resume(returning: okOutput(summary, data: .array(payload)))
            }
        }
    }

    private func createReminder(title: String, listName: String) async -> SkillResult {
        guard let calendar = findCalendar(named: listName) else {
            return errorOutput("I couldn't find a reminders list named \(listName).")
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = calendar

        do {
            try eventStore.save(reminder, commit: true)
            return okOutput("Added \"\(title)\" to \(listName).")
        } catch {
            return errorOutput("I couldn't save that reminder yet.", error: error)
        }
    }

    private func updateReminder(title: String, newTitle: String, listName: String) async -> SkillResult {
        guard let calendar = findCalendar(named: listName) else {
            return errorOutput("I couldn't find a reminders list named \(listName).")
        }
        let notFound = "I couldn't find \"\(title)\" in \(listName)."
        return await withReminder(named: title, in: calendar, includeCompleted: true, notFoundSummary: notFound) { reminder in
            reminder.title = newTitle
            do {
                try eventStore.save(reminder, commit: true)
                return okOutput("Updated \"\(title)\" to \"\(newTitle)\" in \(listName).")
            } catch {
                return errorOutput("I couldn't update that reminder yet.", error: error)
            }
        }
    }

    private func removeReminder(title: String, listName: String) async -> SkillResult {
        guard let calendar = findCalendar(named: listName) else {
            return errorOutput("I couldn't find a reminders list named \(listName).")
        }
        let notFound = "I couldn't find \"\(title)\" in \(listName)."
        return await withReminder(named: title, in: calendar, includeCompleted: true, notFoundSummary: notFound) { reminder in
            do {
                try eventStore.remove(reminder, commit: true)
                return okOutput("Removed \"\(reminder.title ?? title)\" from \(listName).")
            } catch {
                return errorOutput("I couldn't remove that reminder yet.", error: error)
            }
        }
    }

    private func completeReminder(title: String, listName: String) async -> SkillResult {
        guard let calendar = findCalendar(named: listName) else {
            return errorOutput("I couldn't find a reminders list named \(listName).")
        }
        let notFound = "I couldn't find an incomplete reminder named \"\(title)\" in \(listName)."
        return await withReminder(named: title, in: calendar, includeCompleted: false, notFoundSummary: notFound) { reminder in
            reminder.isCompleted = true
            reminder.completionDate = Date()
            do {
                try eventStore.save(reminder, commit: true)
                return okOutput("Marked \"\(reminder.title ?? title)\" complete in \(listName).")
            } catch {
                return errorOutput("I couldn't complete that reminder yet.", error: error)
            }
        }
    }

    private func findCalendar(named listName: String) -> EKCalendar? {
        let normalized = listName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        let calendars = eventStore.calendars(for: .reminder)
        return calendars.first { calendar in
            calendar.title.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    private func withReminder(
        named title: String,
        in calendar: EKCalendar,
        includeCompleted: Bool,
        notFoundSummary: String,
        action: @escaping (EKReminder) -> SkillResult
    ) async -> SkillResult {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return errorOutput(notFoundSummary) }

        let predicate: NSPredicate
        if includeCompleted {
            predicate = eventStore.predicateForReminders(in: [calendar])
        } else {
            predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: [calendar])
        }

        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                guard let reminders else {
                    continuation.resume(returning: errorOutput(notFoundSummary))
                    return
                }
                guard let reminder = reminders.first(where: { reminder in
                    guard let reminderTitle = reminder.title else { return false }
                    return reminderTitle.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                }) else {
                    continuation.resume(returning: errorOutput(notFoundSummary))
                    return
                }

                continuation.resume(returning: action(reminder))
            }
        }
    }

    private func okOutput(_ summary: String, data: JSONValue? = nil) -> SkillResult {
        .ok(summary: summary, data: data)
    }

    private func errorOutput(_ summary: String, error: Error? = nil) -> SkillResult {
        .error(summary: summary, error: error)
    }

    private func clarificationOutput(_ summary: String) -> SkillResult {
        .needsClarification(summary)
    }
}
