import Foundation
import ScryfallKit
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "MagicCardSearch", category: "ScryfallObjectList")

@MainActor
@Observable
class ScryfallObjectList<T: Codable & Sendable> {
    public private(set) var value: LoadableResult<ObjectList<T>, SearchErrorState> = .unloaded

    private let searchUuid = UUID()
    private let fetcher: @Sendable (Int) async throws -> ObjectList<T>
    private var postProcess: ([T]) -> [T]
    private var nextPage = 1
    // Ignore the compiler warning here: if I don't have nonisolated(unsafe), it doesn't compile.
    nonisolated(unsafe) private var task: Task<Void, Never>?

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

    @discardableResult
    func loadNextPage() -> Task<Void, Never> {
        if case .loading = value {
            logger.debug("declining to load next page: already loading uuid=\(self.searchUuid)")
            return Task {}
        }

        if case .loaded(let list, _) = value, list.nextPage == nil {
            logger.debug("declining to load next page: already at the end of the list uuid=\(self.searchUuid)")
            return Task {}
        }

        logger.info("loading page=\(self.nextPage) uuid=\(self.searchUuid)")

        task?.cancel()
        value = .loading(value.latestValue, nil)

        task = Task {
            do {
                let result = try await self.fetcher(self.nextPage)
                guard !Task.isCancelled else { return }

                logger.debug("successfully fetched page=\(self.nextPage) with count=\(result.data.count) items uuid=\(self.searchUuid)")
                self.nextPage += 1
                self.value = .loaded(Self.append(self.value.latestValue, result, postProcess), nil)
            } catch let error as ScryfallKitError {
                // When searching for cards, a 404 means "no results found", not an actual error.
                // Note that this condition assumes that we will never get legit 404s. This should
                // be fine since we only use a small number of fixed URLs, but of course it's not
                // foolproof if Scryfall makes breaking changes.
                if case .scryfallError(let error) = error, error.status == 404 {
                    logger.debug("intercepted Scryfall 404 and set to empty instead uuid=\(self.searchUuid)")
                    // Appending empty is another way of saying to mark is as having no more pages, etc.
                    self.value = .loaded(Self.append(self.value.latestValue, .empty(), postProcess), nil)
                } else {
                    logger.error("error fetching page=\(self.nextPage) uuid=\(self.searchUuid) error=\(error)")
                    self.value = .errored(self.value.latestValue, SearchErrorState(from: error))
                }
            } catch {
                logger.error("error fetching page=\(self.nextPage) uuid=\(self.searchUuid) error=\(error)")
                self.value = .errored(self.value.latestValue, SearchErrorState(from: error))
            }
        }

        return task!
    }

    @discardableResult
    func loadAllRemainingPages() -> Task<Void, Never> {
        if case .loading = value {
            logger.debug("declining to load all remaining pages: already loading uuid=\(self.searchUuid)")
            return Task {}
        }

        if case .loaded(let list, _) = value, list.nextPage == nil {
            logger.debug("declining to load all remaining pages: already at the end of the list uuid=\(self.searchUuid)")
            return Task {}
        }

        logger.info("loading all remaining pages from page=\(self.nextPage) uuid=\(self.searchUuid)")

        task?.cancel()
        value = .loading(value.latestValue, nil)
        var page = self.nextPage

        task = Task {
            var data = self.value.latestValue ?? .empty()
            var shouldContinue = true

            while shouldContinue && !Task.isCancelled {
                do {
                    let result = try await self.fetcher(page)
                    guard !Task.isCancelled else { return }

                    logger.debug("successfully fetched page=\(page) with count=\(result.data.count) items uuid=\(self.searchUuid)")

                    data = Self.append(data, result, postProcess)
                    page += 1
                    shouldContinue = result.hasMore ?? false
                } catch {
                    logger.error("error fetching page=\(page), stopping uuid=\(self.searchUuid) error=\(error)")
                    self.nextPage = page
                    self.value = .errored(data, SearchErrorState(from: error))
                    return
                }
            }

            if !Task.isCancelled {
                logger.info("successfully loaded all remaining pages uuid=\(self.searchUuid)")
                self.nextPage = page
                self.value = .loaded(data, nil)
            }
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
