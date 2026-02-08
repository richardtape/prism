//
//  MusicSkill.swift
//  PrismCore
//
//  Created by Rich Tape on 2026-02-08.
//

import Foundation
#if canImport(MusicKit)
import MusicKit
#endif

/// Apple Music playback skill using ApplicationMusicPlayer.
public struct MusicSkill: Skill {
    public let id: String = "music"
    public let metadata = SkillMetadata(
        name: "Music",
        description: "Control Apple Music playback and playlists."
    )

    public let toolSchema: LLMToolDefinition = LLMToolDefinition(function: .init(
        name: "music",
        description: "Control Apple Music playback and manage playlists.",
        parameters: .object([
            "type": .string("object"),
            "properties": .object([
                "action": .object([
                    "type": .string("string"),
                    "enum": .array([
                        .string("play"),
                        .string("pause"),
                        .string("resume"),
                        .string("skip"),
                        .string("shuffle"),
                        .string("addToPlaylist"),
                        .string("removeFromPlaylist")
                    ])
                ]),
                "query": .object([
                    "type": .string("string"),
                    "description": .string("Song, album, or playlist to play or add/remove.")
                ]),
                "playlist": .object([
                    "type": .string("string"),
                    "description": .string("Target playlist name for add/remove.")
                ]),
                "confirmed": .object([
                    "type": .string("boolean"),
                    "description": .string("Set true when confirming a destructive removal.")
                ])
            ]),
            "required": .array([.string("action")])
        ])
    ))

    public init() {}

    public func execute(call: ToolCall) async throws -> SkillResult {
        #if canImport(MusicKit)
        if #available(macOS 14.0, *) {
            let args = ToolArguments(arguments: call.arguments)
            let action = args.string("action") ?? ""
            let query = args.string("query")
            let playlistName = args.string("playlist")
            let confirmed = args.bool("confirmed") ?? false

            switch action {
            case "play":
                return try await handlePlay(query: query)
            case "pause":
                return handlePause()
            case "resume":
                return try await handleResume()
            case "skip":
                return try await handleSkip()
            case "shuffle":
                return try await handleShuffle(query: query)
            case "addToPlaylist":
                return handleAddToPlaylist(query: query, playlist: playlistName)
            case "removeFromPlaylist":
                return handleRemoveFromPlaylist(query: query, playlist: playlistName, confirmed: confirmed)
            default:
                return errorOutput("Unsupported music action.")
            }
        }
        #endif

        return errorOutput("Apple Music is unavailable on this system.")
    }

    @available(macOS 14.0, *)
    private func handlePlay(query: String?) async throws -> SkillResult {
        let player = ApplicationMusicPlayer.shared
        guard let query, !query.isEmpty else {
            try await player.play()
            return okOutput("Resuming Apple Music.")
        }

        let libraryItem = try await searchLibrary(term: query)
        let item: PlayableResult?
        if let libraryItem {
            item = libraryItem
        } else {
            item = await searchCatalog(term: query)
        }
        if let item {
            player.queue = makeQueue(from: item)
            try await player.play()
            return okOutput("Playing \(item.titleForSummary).")
        }

        return errorOutput("I couldn't find that in your library or Apple Music.")
    }

    @available(macOS 14.0, *)
    private func handlePause() -> SkillResult {
        let player = ApplicationMusicPlayer.shared
        player.pause()
        return okOutput("Paused Apple Music.")
    }

    @available(macOS 14.0, *)
    private func handleResume() async throws -> SkillResult {
        let player = ApplicationMusicPlayer.shared
        try await player.play()
        return okOutput("Resuming Apple Music.")
    }

    @available(macOS 14.0, *)
    private func handleSkip() async throws -> SkillResult {
        let player = ApplicationMusicPlayer.shared
        try await player.skipToNextEntry()
        return okOutput("Skipped to the next track.")
    }

    @available(macOS 14.0, *)
    private func handleShuffle(query: String?) async throws -> SkillResult {
        let player = ApplicationMusicPlayer.shared
        if let query, !query.isEmpty {
            let libraryItem = try await searchLibrary(term: query)
            let item: PlayableResult?
            if let libraryItem {
                item = libraryItem
            } else {
                item = await searchCatalog(term: query)
            }
            if let item {
                player.queue = makeQueue(from: item)
            } else {
                return errorOutput("I couldn't find that to shuffle.")
            }
        }

        let currentMode = player.state.shuffleMode ?? .off
        let newMode: MusicPlayer.ShuffleMode = (currentMode == .off) ? .songs : .off
        player.state.shuffleMode = newMode
        if newMode == .songs {
            try await player.play()
            return okOutput("Shuffle is on.")
        }
        return okOutput("Shuffle is off.")
    }

    @available(macOS 14.0, *)
    private func handleAddToPlaylist(query: String?, playlist: String?) -> SkillResult {
        guard let playlist, !playlist.isEmpty else {
            return clarificationOutput("Which playlist should I add this to?")
        }
        guard let query, !query.isEmpty else {
            return clarificationOutput("What should I add to \(playlist)?")
        }
        return errorOutput("Playlist editing isn't available on macOS yet.")
    }

    @available(macOS 14.0, *)
    private func handleRemoveFromPlaylist(query: String?, playlist: String?, confirmed: Bool) -> SkillResult {
        guard let playlist, !playlist.isEmpty else {
            return clarificationOutput("Which playlist should I remove this from?")
        }
        guard let query, !query.isEmpty else {
            return clarificationOutput("What should I remove from \(playlist)?")
        }
        guard confirmed else {
            return pendingConfirmationOutput("Remove \"\(query)\" from \(playlist)?")
        }
        return errorOutput("Playlist editing isn't available on macOS yet.")
    }

    @available(macOS 14.0, *)
    private func searchLibrary(term: String) async throws -> PlayableResult? {
        var request = MusicLibrarySearchRequest(term: term, types: [Song.self, Album.self, Playlist.self])
        request.limit = 5
        let response = try await request.response()
        if let playlist = response.playlists.first {
            return .playlist(playlist)
        }
        if let song = response.songs.first {
            return .song(song)
        }
        if let album = response.albums.first {
            return .album(album)
        }
        return nil
    }

    @available(macOS 14.0, *)
    private func searchCatalog(term: String) async -> PlayableResult? {
        let request = MusicCatalogSearchRequest(term: term, types: [Song.self, Album.self, Playlist.self])
        do {
            let response = try await request.response()
            if let playlist = response.playlists.first {
                return .playlist(playlist)
            }
            if let song = response.songs.first {
                return .song(song)
            }
            if let album = response.albums.first {
                return .album(album)
            }
        } catch {
            return nil
        }
        return nil
    }

    @available(macOS 14.0, *)
    private func makeQueue(from result: PlayableResult) -> ApplicationMusicPlayer.Queue {
        switch result {
        case .song(let song):
            return ApplicationMusicPlayer.Queue(for: [song])
        case .album(let album):
            return ApplicationMusicPlayer.Queue(for: [album])
        case .playlist(let playlist):
            return ApplicationMusicPlayer.Queue(for: [playlist])
        }
    }

    private func okOutput(_ summary: String) -> SkillResult {
        .ok(summary: summary)
    }

    private func errorOutput(_ summary: String) -> SkillResult {
        .error(summary: summary)
    }

    private func clarificationOutput(_ summary: String) -> SkillResult {
        .needsClarification(summary)
    }

    private func pendingConfirmationOutput(_ prompt: String) -> SkillResult {
        .pendingConfirmation(prompt: prompt)
    }
}

#if canImport(MusicKit)
@available(macOS 14.0, *)
private enum PlayableResult {
    case song(Song)
    case album(Album)
    case playlist(Playlist)

    var titleForSummary: String {
        switch self {
        case .song(let song):
            return "\(song.title) by \(song.artistName)"
        case .album(let album):
            return album.title
        case .playlist(let playlist):
            return playlist.name
        }
    }
}
#endif
