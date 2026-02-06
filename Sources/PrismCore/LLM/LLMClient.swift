//
//  LLMClient.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-06.
//

import Foundation

/// OpenAI-compatible client for chat completions.
public final class LLMClient {
    private let configStore: ConfigStore
    private let session: URLSession
    private let timeout: TimeInterval
    private let maxRetries: Int

    public init(
        configStore: ConfigStore,
        session: URLSession = .shared,
        timeout: TimeInterval = 30,
        maxRetries: Int = 1
    ) {
        self.configStore = configStore
        self.session = session
        self.timeout = timeout
        self.maxRetries = maxRetries
    }

    /// Executes a non-streaming chat completion request.
    public func complete(_ request: LLMRequest) async throws -> LLMCompletion {
        let config = try loadConfig()
        let resolvedRequest = try resolveRequest(request, config: config)
        return try await performRequest(config: config, request: resolvedRequest, attempt: 0)
    }

    /// Streams a chat completion request using Server-Sent Events when supported.
    public func streamComplete(_ request: LLMRequest) async throws -> AsyncStream<LLMEvent> {
        let config = try loadConfig()
        let resolvedRequest = try resolveRequest(request, config: config)

        if #available(macOS 12.0, *) {
            return try await streamCompleteUsingBytes(config: config, request: resolvedRequest)
        }

        let session = self.session
        let timeout = self.timeout
        let fallbackConfig = config
        let fallbackRequest = resolvedRequest

        return AsyncStream { continuation in
            Task {
                do {
                    let completion = try await Self.sendRequest(
                        session: session,
                        timeout: timeout,
                        config: fallbackConfig,
                        request: fallbackRequest
                    )
                    if let content = completion.message.content, !content.isEmpty {
                        continuation.yield(.token(content))
                    }
                    continuation.yield(.done)
                } catch {
                    continuation.yield(.error(LLMErrorMapper.map(error)))
                }
                continuation.finish()
            }
        }
    }

    @available(macOS 12.0, *)
    private func streamCompleteUsingBytes(config: LLMConfig, request: LLMRequest) async throws -> AsyncStream<LLMEvent> {
        let endpoint = try Self.chatCompletionsURL(from: config.endpoint)
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = timeout
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        let payload = try encoder.encode(LLMRequest(
            model: request.model,
            messages: request.messages,
            tools: request.tools,
            temperature: request.temperature,
            maxTokens: request.maxTokens,
            stream: true
        ))
        urlRequest.httpBody = payload

        let (byteStream, response) = try await session.bytes(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.network("Missing HTTP response")
        }

        if httpResponse.statusCode == 401 {
            throw LLMError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LLMError.server("HTTP \(httpResponse.statusCode)")
        }

        let parser = LLMStreamParser()

        return AsyncStream { continuation in
            Task {
                for try await line in byteStream.lines {
                    let events = parser.parse(lines: [line])
                    for event in events {
                        continuation.yield(event)
                        if case .done = event {
                            continuation.finish()
                            return
                        }
                    }
                }
                continuation.finish()
            }
        }
    }

    /// Fetches the list of available models from the configured endpoint.
    public func listModels() async throws -> [String] {
        let config = try loadConfig()
        return try await Self.listModels(session: session, timeout: timeout, config: config)
    }

    /// Fetches the list of available models using explicit endpoint and API key values.
    public func listModels(endpoint: String, apiKey: String) async throws -> [String] {
        let config = LLMConfig(endpoint: endpoint, apiKey: apiKey, model: nil)
        return try await Self.listModels(session: session, timeout: timeout, config: config)
    }

    private func performRequest(config: LLMConfig, request: LLMRequest, attempt: Int) async throws -> LLMCompletion {
        do {
            return try await sendRequest(config: config, request: request)
        } catch {
            let mappedError = LLMErrorMapper.map(error)
            if attempt < maxRetries, shouldRetry(mappedError) {
                return try await performRequest(config: config, request: request, attempt: attempt + 1)
            }
            throw mappedError
        }
    }

    private func sendRequest(config: LLMConfig, request: LLMRequest) async throws -> LLMCompletion {
        return try await Self.sendRequest(session: session, timeout: timeout, config: config, request: request)
    }

    private static func sendRequest(
        session: URLSession,
        timeout: TimeInterval,
        config: LLMConfig,
        request: LLMRequest
    ) async throws -> LLMCompletion {
        let endpoint = try chatCompletionsURL(from: config.endpoint)
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = timeout
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        let payload = try encoder.encode(request)
        urlRequest.httpBody = payload

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.network("Missing HTTP response")
        }

        if httpResponse.statusCode == 401 {
            throw LLMError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let apiError = try? JSONDecoder().decode(LLMAPIErrorResponse.self, from: data) {
                throw LLMError.server(apiError.error.message)
            }
            throw LLMError.server("HTTP \(httpResponse.statusCode)")
        }

        let responsePayload = try JSONDecoder().decode(LLMCompletionResponse.self, from: data)
        guard let choice = responsePayload.choices.first else {
            throw LLMError.decoding("No choices returned")
        }

        return LLMCompletion(
            message: choice.message,
            finishReason: choice.finishReason,
            model: responsePayload.model,
            usage: responsePayload.usage
        )
    }

    private func loadConfig() throws -> LLMConfig {
        guard let config = try configStore.load() else {
            throw LLMError.invalidRequest("Missing LLM configuration")
        }
        if config.endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw LLMError.invalidRequest("Endpoint URL is required")
        }
        if config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw LLMError.invalidRequest("API key is required")
        }
        return config
    }

    private func resolveRequest(_ request: LLMRequest, config: LLMConfig) throws -> LLMRequest {
        let model = request.model.isEmpty ? (config.model ?? "") : request.model
        guard !model.isEmpty else {
            throw LLMError.invalidRequest("Model is required")
        }
        return LLMRequest(
            model: model,
            messages: request.messages,
            tools: request.tools,
            temperature: request.temperature,
            maxTokens: request.maxTokens,
            stream: false
        )
    }

    private static func chatCompletionsURL(from endpoint: String) throws -> URL {
        guard let baseURL = URL(string: endpoint) else {
            throw LLMError.invalidRequest("Invalid endpoint URL")
        }

        if baseURL.path.hasSuffix("/chat/completions") {
            return baseURL
        }

        let basePath = baseURL.path
        let suffix = basePath.contains("/v1") ? "/chat/completions" : "/v1/chat/completions"
        return try appendingPath(suffix, to: baseURL)
    }

    private static func modelsURL(from endpoint: String) throws -> URL {
        guard let baseURL = URL(string: endpoint) else {
            throw LLMError.invalidRequest("Invalid endpoint URL")
        }

        if baseURL.path.hasSuffix("/models") {
            return baseURL
        }

        let basePath = baseURL.path
        let suffix = basePath.contains("/v1") ? "/models" : "/v1/models"
        return try appendingPath(suffix, to: baseURL)
    }

    private static func listModels(session: URLSession, timeout: TimeInterval, config: LLMConfig) async throws -> [String] {
        let endpoint = try modelsURL(from: config.endpoint)
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = timeout
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.network("Missing HTTP response")
        }

        if httpResponse.statusCode == 401 {
            throw LLMError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let apiError = try? JSONDecoder().decode(LLMAPIErrorResponse.self, from: data) {
                throw LLMError.server(apiError.error.message)
            }
            throw LLMError.server("HTTP \(httpResponse.statusCode)")
        }

        let payload = try JSONDecoder().decode(LLMModelsResponse.self, from: data)
        return payload.data.map(\.id).sorted()
    }

    private static func appendingPath(_ path: String, to baseURL: URL) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw LLMError.invalidRequest("Invalid endpoint URL")
        }
        var basePath = components.path
        if basePath.hasSuffix("/") {
            basePath.removeLast()
        }
        let normalized = path.hasPrefix("/") ? path : "/\(path)"
        components.path = basePath + normalized
        guard let url = components.url else {
            throw LLMError.invalidRequest("Invalid endpoint URL")
        }
        return url
    }

    private func shouldRetry(_ error: LLMError) -> Bool {
        switch error {
        case .network, .server, .timeout:
            return true
        default:
            return false
        }
    }

    // Timeout is enforced via URLRequest.timeoutInterval.
}

private struct LLMCompletionResponse: Codable {
    let model: String
    let choices: [LLMChoice]
    let usage: LLMUsage?
}

private struct LLMChoice: Codable {
    let message: LLMMessage
    let finishReason: String?

    private enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

private struct LLMAPIErrorResponse: Codable {
    struct Payload: Codable {
        let message: String
        let type: String?
        let code: String?
    }

    let error: Payload
}
