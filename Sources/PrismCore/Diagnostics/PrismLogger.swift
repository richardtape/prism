//
//  PrismLogger.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-07.
//

import Foundation
import os

/// Shared log helpers for Prism diagnostics.
public enum PrismLogger {
    private static let subsystem = "com.prism"
    private static let llmCategory = "LLM"

    public static func llmInfo(_ message: String) {
        log(message, type: .info)
    }

    public static func llmWarning(_ message: String) {
        log(message, type: .default)
    }

    public static func llmError(_ message: String) {
        log(message, type: .error)
    }

    private static func log(_ message: String, type: OSLogType) {
        if #available(macOS 11.0, *) {
            let logger = Logger(subsystem: subsystem, category: llmCategory)
            switch type {
            case .error:
                logger.error("\(message, privacy: .public)")
            case .fault:
                logger.fault("\(message, privacy: .public)")
            case .debug:
                logger.debug("\(message, privacy: .public)")
            case .info:
                logger.info("\(message, privacy: .public)")
            default:
                logger.log("\(message, privacy: .public)")
            }
        } else {
            let log = OSLog(subsystem: subsystem, category: llmCategory)
            os_log("%{public}@", log: log, type: type, message)
        }
    }
}
