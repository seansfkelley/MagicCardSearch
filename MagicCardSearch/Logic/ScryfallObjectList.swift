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

    func loadNextPage() -> Task<Void, Never> {
        if case .loading = value {
            logger.debug("declining to load next page: already loading")
            return Task {}
        }

        if case .loaded(let list, _) = value, list.nextPage == nil {
            logger.debug("declining to load next page: already at the end of the list")
            return Task {}
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
            } catch let error as ScryfallKitError {
                // When searching for cards, a 404 means "no results found", not an actual error.
                // Note that this condition assumes that we will never get legit 404s. This should
                // be fine since we only use a small number of fixed URLs, but of course it's not
                // foolproof if Scryfall makes breaking changes.
                if case .scryfallError(let error) = error, error.status == 404 {
                    logger.debug("intercepted Scryfall 404 and set to empty instead")
                    // Appending empty is another way of saying to mark is as having no more pages, etc.
                    self.value = .loaded(append(self.value.latestValue, .empty()), nil)
                } else {
                    logger.error("error fetching next page", metadata: [
                        "page": "\(nextPage)",
                        "error": "\(error)",
                    ])
                    self.value = .errored(self.value.latestValue, SearchErrorState(from: error))
                }
            } catch {
                logger.error("error fetching next page", metadata: [
                    "page": "\(nextPage)",
                    "error": "\(error)",
                ])
                self.value = .errored(self.value.latestValue, SearchErrorState(from: error))
            }
        }

        return task!
    }

    func loadAllRemainingPages() -> Task<Void, Never> {
        if case .loading = value {
            logger.debug("declining to load all remaining pages: already loading")
            return Task {}
        }

        if case .loaded(let list, _) = value, list.nextPage == nil {
            logger.debug("declining to load all remaining pages: already at the end of the list")
            return Task {}
        }

        logger.info("loading all remaining pages", metadata: [
            "fromPage": "\(nextPage)",
        ])

        task?.cancel()
        value = .loading(value.latestValue, nil)

        task = Task {
            var currentData = self.value.latestValue ?? .empty()
            var shouldContinue = true

            while shouldContinue && !Task.isCancelled {
                do {
                    let result = try await self.fetcher(self.nextPage)
                    guard !Task.isCancelled else { return }

                    logger.debug("successfully fetched page", metadata: [
                        "page": "\(nextPage)",
                    ])

                    currentData = self.append(currentData, result)
                    self.nextPage += 1
                    shouldContinue = result.hasMore ?? false
                } catch {
                    logger.error("error fetching page, stopping", metadata: [
                        "page": "\(nextPage)",
                        "error": "\(error)",
                    ])
                    self.value = .errored(currentData, SearchErrorState(from: error))
                    return
                }
            }

            if !Task.isCancelled {
                logger.info("successfully loaded all remaining pages")
                self.value = .loaded(currentData, nil)
            }
        }

        return task!
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
