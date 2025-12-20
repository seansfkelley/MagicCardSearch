struct ParenthesizedQuery {
    // Note that these are not guaranteed to be all filters; on parse error we stop trying and
    // return only those that we have definitely identified so far.
    let filters: [Range<String.Index>]
}
