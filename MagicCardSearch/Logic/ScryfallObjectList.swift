//
//  ScryfallObjectList.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-31.
//
import ScryfallKit
import Logging
import SwiftUI

private let logger = Logger(label: "ScryfallObjectList")

@MainActor
@Observable
class ScryfallObjectList<T: Codable & Sendable> {
    public private(set) var value: LoadableResult<ObjectList<T>, SearchErrorState> = .unloaded

    private var fetcher: @Sendable (Int) async throws -> ObjectList<T>
    private var nextPage = 1
    nonisolated(unsafe) private var task: Task<Void, Never>?

    init(_ fetcher: @escaping @Sendable (Int) async throws -> ObjectList<T>) {
        self.fetcher = fetcher
    }

    public static func empty() -> ScryfallObjectList<T> {
        ScryfallObjectList { _ in .empty() }
    }

    func clearWarnings() {
        value = value.mapValue { list in
            ObjectList(
                data: list.data,
                hasMore: list.hasMore,
                nextPage: list.nextPage,
                totalCards: list.totalCards,
                warnings: [],
            )
        }
    }

    func loadNextPage() {
        if case .loading = value {
            logger.debug("declining to load next page: already loading")
            return
        }

        if case .loaded(let list, _) = value, list.nextPage == nil {
            logger.debug("declining to load next page: already at the end of the list")
            return
        }

        logger.info("loading next page", metadata: [
            "page": "\(nextPage)",
        ])

        task?.cancel()
        value = .loading(value.latestValue, nil)

        task = Task {
            do {
                let result = try await self.fetcher(self.nextPage)
                guard !Task.isCancelled else { return }

                logger.debug("successfully fetched next page", metadata: [
                    "page": "\(nextPage)",
                ])
                self.nextPage += 1
                self.value = .loaded(self.append(self.value.latestValue, result), nil)
            } catch {
                logger.error("error fetching next page", metadata: [
                    "page": "\(nextPage)",
                    "error": "\(error)",
                ])
                self.value = .errored(self.value.latestValue, SearchErrorState(from: error))
            }
        }
    }

    private func append(_ first: ObjectList<T>?, _ second: ObjectList<T>) -> ObjectList<T> {
        guard let first else { return second }

        return ObjectList(
            data: first.data + second.data,
            hasMore: second.hasMore,
            nextPage: second.nextPage,
            totalCards: first.totalCards,
            warnings: first.warnings,
        )
    }

    deinit {
        task?.cancel()
    }
}

public extension ObjectList {
    static func empty() -> ObjectList<T> {
        ObjectList<T>(data: [], hasMore: false, nextPage: nil, totalCards: 0, warnings: [])
    }
}
