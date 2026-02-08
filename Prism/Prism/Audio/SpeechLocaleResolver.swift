//
//  SpeechLocaleResolver.swift
//  Prism
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation
import Speech

/// Resolves the effective on-device speech recognition locale.
struct SpeechLocaleResolver {
    struct Resolution: Sendable, Equatable {
        let locale: Locale
        let identifier: String
        let displayName: String
        let usedFallback: Bool
    }

    static func resolveOnDeviceLocale(preferredIdentifier: String) -> Resolution {
        let trimmed = preferredIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let preferredLanguages = Locale.preferredLanguages
        let requestedIdentifier = trimmed.isEmpty ? (preferredLanguages.first ?? Locale.current.identifier) : trimmed
        let requestedLocale = Locale(identifier: requestedIdentifier)

        let supportedLocales = SFSpeechRecognizer.supportedLocales()
        let onDeviceLocales = supportedLocales
            .filter { locale in
                guard let recognizer = SFSpeechRecognizer(locale: locale) else { return false }
                return recognizer.supportsOnDeviceRecognition
            }
            .sorted { $0.identifier < $1.identifier }

        let orderedPreferredIdentifiers = ([requestedIdentifier] + preferredLanguages + [Locale.current.identifier])
            .map { $0.replacingOccurrences(of: "-", with: "_") }
            .filter { !$0.isEmpty }
            .uniqued()

        let displayName: (Locale) -> String = { locale in
            locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
        }

        for identifier in orderedPreferredIdentifiers {
            if let match = onDeviceLocales.first(where: { $0.identifier == identifier }) {
                return Resolution(
                    locale: match,
                    identifier: match.identifier,
                    displayName: displayName(match),
                    usedFallback: identifier != requestedIdentifier
                )
            }
        }

        for identifier in orderedPreferredIdentifiers {
            let requestedLanguageCode = languageCode(from: identifier)
            if let requestedLanguageCode,
               let match = onDeviceLocales.first(where: { languageCode(for: $0) == requestedLanguageCode }) {
                return Resolution(
                    locale: match,
                    identifier: match.identifier,
                    displayName: displayName(match),
                    usedFallback: true
                )
            }
        }

        if let match = onDeviceLocales.first(where: { $0.identifier == "en_US" }) {
            return Resolution(
                locale: match,
                identifier: match.identifier,
                displayName: displayName(match),
                usedFallback: true
            )
        }

        if let match = onDeviceLocales.first {
            return Resolution(
                locale: match,
                identifier: match.identifier,
                displayName: displayName(match),
                usedFallback: true
            )
        }

        return Resolution(
            locale: requestedLocale,
            identifier: requestedIdentifier,
            displayName: displayName(requestedLocale),
            usedFallback: true
        )
    }

    static func languageCode(for locale: Locale) -> String? {
        if #available(macOS 13.0, *) {
            return locale.language.languageCode?.identifier
        }
        let identifier = locale.identifier
        let parts = identifier.split(whereSeparator: { $0 == "_" || $0 == "-" })
        return parts.first.map(String.init)
    }

    private static func languageCode(from identifier: String) -> String? {
        languageCode(for: Locale(identifier: identifier))
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
