import ScryfallKit

struct AutocompleteConstants {
    // These are really noisy in the search results and I can't imagine anyone ever wants them.
    //
    // Maybe in the future we could suggest these if you have narrowed the results far enough that
    // you might actually want to see the 800 memorabilia variants for Avatar, but not when you've
    // only typed "a".
    static let ignoredSetTypes: Set<MTGSet.Kind> = [
        .token,
        .promo,
        .memorabilia,
    ]
}
