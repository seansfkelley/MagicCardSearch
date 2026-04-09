import Foundation
import ScryfallKit
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "MagicCardSearch", category: "ScryfallObjectList")

@MainActor
@Observable
class ScryfallObjectList<T: Codable & Sendable> {
    public private(set) var value: LoadableResult<ObjectList<T>, SearchError> = .unloaded

    private let searchUuid = UUID()
    private let fetcher: @Sendable (Int) async throws -> ObjectList<T>
    private var postProcess: ([T]) -> [T]
    private var nextPage = 1
    // Ignore the compiler warning here: if I don't have nonisolated(unsafe), it doesn't compile.
    nonisolated(unsafe) private var task: Task<Void, any Error>?

    init(
        _ fetcher: @escaping @Sendable (Int) async throws -> ObjectList<T>,
        postProcess: @escaping ([T]) -> [T] = (\.self)
    ) {
        self.fetcher = fetcher
        self.postProcess = postProcess
    }

    public static func empty() -> ScryfallObjectList<T> {
        ScryfallObjectList { _ in .empty() }
    }

    // This horrible shit is because any attempt to map .value onto another Loadable with some
    // post-processing in the view -- in order to avoid recalculating that value on every single
    // frame, should that be desirable -- gets into some kind of insane state where SwiftUI appears
    // to be dropping updates on the floor, perhaps due to complex @Observable interactions. I would
    // like to delete this but I don't know immediately how to do it more sanely. Check commit
    // 873c401e356f58890fb661e678baf2037c50f202 for more on the update dropping.
    //
    // The reason this method doesn't just call the closure is because of Swift's capturing
    // semantics, to wit, the default with View structs is that it captures the value, so if your
    // processing depends on a changing value, it would be stale. Forcing you to redefine it means
    // at least it won't be stale when you imperatively trigger this.
    func reprocess(_ postProcess: @escaping ([T]) -> [T]) {
        self.postProcess = postProcess
        // swiftlint:disable:next trailing_closure
        value = value.map(value: { Self.append(nil, $0, postProcess) })
    }

    func cancel() {
        task?.cancel()
    }

    @discardableResult
    func loadFirstPage() -> Task<Void, any Error> {
        // Ensure the first page is loaded. Used when the list object is cached and reused, and it
        // may have been cancelled before the first page successfully loaded. Contrast loadNextPage,
        // which will always load the next page even if we only wanted the first (in the example
        // given).
        if nextPage == 1 {
            return loadNextPage()
        } else {
            logger.debug("declining to load first page: already loaded uuid=\(self.searchUuid)")
            return Task {}
        }
    }

    @discardableResult
    func loadNextPage() -> Task<Void, any Error> {
        if case .loading = value {
            logger.debug("declining to load next page: already loading uuid=\(self.searchUuid)")
            return Task<Void, any Error> {}
        }

        if case .loaded(let list, _) = value, list.nextPage == nil {
            logger.debug("declining to load next page: already at the end of the list uuid=\(self.searchUuid)")
            return Task<Void, any Error> {}
        }

        logger.info("loading page=\(self.nextPage) uuid=\(self.searchUuid)")

        task?.cancel()
        value = .loading(value.latestValue, nil)

        task = Task {
            do {
                let result = try await fetcher(nextPage)
                // A possible optimization is that, since we already did the hard work of fetching
                // and waiting, we could ignore cancellation and just append the results. That work
                // is trivial and since these list objects are often cached, it could save us work
                // later if this list is used again. However, this interacts badly with any
                // concurrent loads or load-alls that might be requested by the caller -- we don't
                // know what order they'll come back so we might end up appending all kinds of
                // nonsense or losing track of which page we're on.
                try Task.checkCancellation()

                logger.info("successfully fetched page=\(self.nextPage) with count=\(result.data.count) items uuid=\(self.searchUuid)")
                nextPage += 1
                value = .loaded(Self.append(value.latestValue, result, postProcess), nil)
            } catch let error as CancellationError {
                logger.info("cancelled while fetching page=\(self.nextPage)  uuid=\(self.searchUuid)")
                throw error
            } catch let error as ScryfallKitError {
                // When searching for cards, a 404 means "no results found", not an actual error.
                // Note that this condition assumes that we will never get legit 404s. This should
                // be fine since we only use a small number of fixed URLs, but of course it's not
                // foolproof if Scryfall makes breaking changes.
                if case .scryfallError(let error) = error, error.status == 404 {
                    logger.info("intercepted Scryfall 404 and set to empty instead uuid=\(self.searchUuid)")
                    // Appending empty is another way of saying to mark is as having no more pages, etc.
                    value = .loaded(Self.append(value.latestValue, .empty(), postProcess), nil)
                } else {
                    logger.error("error fetching page=\(self.nextPage) uuid=\(self.searchUuid) error=\(error)")
                    value = .errored(value.latestValue, SearchError(from: error))
                }
            } catch {
                logger.error("error fetching page=\(self.nextPage) uuid=\(self.searchUuid) error=\(error)")
                value = .errored(self.value.latestValue, SearchError(from: error))
            }
        }

        return task!
    }

    @discardableResult
    func loadAllRemainingPages() -> Task<Void, any Error> {
        if case .loading = value {
            logger.debug("declining to load all remaining pages: already loading uuid=\(self.searchUuid)")
            return Task<Void, any Error> {}
        }

        if case .loaded(let list, _) = value, list.nextPage == nil {
            logger.debug("declining to load all remaining pages: already at the end of the list uuid=\(self.searchUuid)")
            return Task<Void, any Error> {}
        }

        logger.info("loading all remaining pages from page=\(self.nextPage) uuid=\(self.searchUuid)")

        task?.cancel()
        value = .loading(value.latestValue, nil)
        var page = self.nextPage

        task = Task {
            var data = self.value.latestValue ?? .empty()
            var hasMorePages = true

            while hasMorePages {
                do {
                    let result = try await fetcher(page)
                    // See above for why we must respect cancellation.
                    try Task.checkCancellation()

                    logger.debug("successfully fetched page=\(page) with count=\(result.data.count) items uuid=\(self.searchUuid)")

                    data = Self.append(data, result, postProcess)
                    page += 1
                    hasMorePages = result.hasMore ?? false
                } catch let error as CancellationError {
                    logger.info("cancelled while fetching page=\(page), stopping uuid=\(self.searchUuid)")
                    throw error
                } catch {
                    logger.error("error fetching page=\(page), stopping uuid=\(self.searchUuid) error=\(error)")
                    nextPage = page
                    value = .errored(data, SearchError(from: error))
                    return
                }
            }

            logger.info("successfully loaded all remaining pages uuid=\(self.searchUuid)")
            nextPage = page
            value = .loaded(data, nil)
        }

        return task!
    }

    private static func append(_ first: ObjectList<T>?, _ second: ObjectList<T>, _ postProcess: ([T]) -> [T]) -> ObjectList<T> {
        ObjectList(
            data: postProcess((first?.data ?? []) + second.data),
            hasMore: second.hasMore,
            nextPage: second.nextPage,
            totalCards: first?.totalCards ?? second.totalCards,
            warnings: first?.warnings ?? second.warnings,
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
