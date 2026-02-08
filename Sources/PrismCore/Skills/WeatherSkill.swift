//
//  WeatherSkill.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-08.
//

import CoreLocation
import Foundation
import GRDB
#if canImport(WeatherKit)
import WeatherKit
#endif

/// WeatherKit-backed skill for current, minute, and daily forecasts.
public struct WeatherSkill: Skill {
    public let id: String = "weather"
    public let metadata = SkillMetadata(
        name: "Weather",
        description: "Get current conditions and upcoming forecast details."
    )

    public let toolSchema: LLMToolDefinition = LLMToolDefinition(function: .init(
        name: "weather",
        description: "Fetch current conditions plus minute and daily forecast data.",
        parameters: .object([
            "type": .string("object"),
            "properties": .object([
                "action": .object([
                    "type": .string("string"),
                    "enum": .array([.string("get_forecast")])
                ]),
                "location": .object([
                    "type": .string("string"),
                    "description": .string("Optional location name, e.g. 'Seattle' or '94107'.")
                ])
            ]),
            "required": .array([.string("action")])
        ])
    ))

    private let queue: DatabaseQueue
    private let unitsKey: String

    public init(queue: DatabaseQueue, unitsKey: String) {
        self.queue = queue
        self.unitsKey = unitsKey
    }

    public func execute(call: ToolCall) async throws -> SkillResult {
        let args = ToolArguments(arguments: call.arguments)
        let action = args.string("action") ?? "get_forecast"
        guard action == "get_forecast" else {
            return .error(summary: "Unsupported weather action.")
        }

        do {
            let locationProvider = WeatherLocationProvider()
            let resolved = try await locationProvider.resolve(locationQuery: args.string("location"))
            return try await fetchForecast(for: resolved.coordinate, displayName: resolved.displayName)
        } catch {
            return .error(summary: "I couldn't fetch weather data yet.", error: error)
        }
    }

    private func fetchForecast(for location: CLLocation, displayName: String) async throws -> SkillResult {
        #if canImport(WeatherKit)
        if #available(macOS 13.0, *) {
            let service = WeatherService.shared
            let weather = try await service.weather(for: location)
            let units = loadUnits()
            let formatter = WeatherFormatter(units: units)

            let currentSummary = formatter.currentSummary(weather.currentWeather)
            let dailySummary = formatter.dailySummary(weather.dailyForecast)
            let minuteSummary = weather.minuteForecast.map { formatter.minuteSummary($0) } ?? ""

            let summaryParts = [currentSummary, minuteSummary, dailySummary].filter { !$0.isEmpty }
            let summary = summaryParts.joined(separator: " ")

            let data: JSONValue = .object([
                "location": .string(displayName),
                "current": formatter.currentPayload(weather.currentWeather),
                "minute": weather.minuteForecast.map { formatter.minutePayload($0) } ?? .object([:]),
                "daily": formatter.dailyPayload(weather.dailyForecast)
            ])

            return .ok(summary: summary, data: data)
        }
        #endif

        return .error(summary: "WeatherKit is unavailable on this system.")
    }

    private func loadUnits() -> WeatherUnits {
        let store = SettingsStore(queue: queue)
        return WeatherSettingsLoader(store: store, unitsKey: unitsKey).loadUnits()
    }
}

#if canImport(WeatherKit)
@available(macOS 13.0, *)
private struct WeatherFormatter {
    let units: WeatherUnits

    func currentSummary(_ current: CurrentWeather) -> String {
        let temperature = format(current.temperature)
        let condition = String(describing: current.condition).replacingOccurrences(of: "_", with: " ")
        return "Now in \(temperature) and \(condition)."
    }

    func dailySummary(_ daily: Forecast<DayWeather>) -> String {
        guard let today = daily.forecast.first else { return "" }
        let high = format(today.highTemperature)
        let low = format(today.lowTemperature)
        let condition = String(describing: today.condition).replacingOccurrences(of: "_", with: " ")
        return "Today: \(condition) with a high of \(high) and low of \(low)."
    }

    func minuteSummary(_ minute: Forecast<MinuteWeather>) -> String {
        guard let maxChance = minute.forecast.map({ $0.precipitationChance }).max() else { return "" }
        let percentage = Int(maxChance * 100)
        return "Next hour precipitation chance up to \(percentage)%."
    }

    func currentPayload(_ current: CurrentWeather) -> JSONValue {
        .object([
            "temperature": .string(format(current.temperature)),
            "condition": .string(String(describing: current.condition))
        ])
    }

    func minutePayload(_ minute: Forecast<MinuteWeather>) -> JSONValue {
        let maxChance = minute.forecast.map({ $0.precipitationChance }).max() ?? 0
        return .object([
            "precipitationChance": .number(maxChance)
        ])
    }

    func dailyPayload(_ daily: Forecast<DayWeather>) -> JSONValue {
        guard let today = daily.forecast.first else {
            return .object([:])
        }
        return .object([
            "high": .string(format(today.highTemperature)),
            "low": .string(format(today.lowTemperature)),
            "condition": .string(String(describing: today.condition))
        ])
    }

    private func format(_ measurement: Measurement<UnitTemperature>) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .short
        formatter.numberFormatter.maximumFractionDigits = 0
        formatter.locale = .current
        switch units {
        case .system:
            formatter.unitOptions = .naturalScale
            return formatter.string(from: measurement)
        case .metric:
            return formatter.string(from: measurement.converted(to: .celsius))
        case .imperial:
            return formatter.string(from: measurement.converted(to: .fahrenheit))
        }
    }
}
#endif
