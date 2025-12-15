//
//  LoadableResult.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-15.
//
enum LoadableResult<T> {
    case unloaded
    case loading(Result<T, Error>?)
    case loaded(Result<T, Error>)
    
    var latestResult: Result<T, Error>? {
        return switch self {
        case .unloaded: nil
        case .loading(let result): result
        case .loaded(let result): result
        }
    }
}
