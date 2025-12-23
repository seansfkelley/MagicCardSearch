//
//  removeAutoinsertedWhitespace.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-23.
//
func removeAutoinsertedWhitespace(_ current: String) -> String? {
    guard let tokens = try? lexParenthesizedQuery(current, allowingUnterminatedLiterals: true) else {
        return nil
    }

    var result = current

    for i in stride(from: tokens.count - 1, through: 2, by: -1) {
        let (nameToken, nameCode) = tokens[i]
        let (andToken, andCode) = tokens[i - 1]
        let (filterToken, filterCode) = tokens[i - 2]

        guard nameCode == .Verbatim,
              andCode == .And,
              filterCode == .Verbatim,
              case .filter(_, _, let term) = PartialSearchFilter.from(filterToken.content).content,
              term.incompleteContent.isEmpty,
              case .name(_, let nameTerm) = PartialSearchFilter.from(nameToken.content).content,
              !nameTerm.incompleteContent.isEmpty else {
            continue
        }

        result.removeSubrange(andToken.range)
    }

    return result
}
