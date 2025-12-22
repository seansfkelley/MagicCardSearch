//
//  CurrentFilterTracker.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-22.
//

import SwiftUI

/// Tracks the current filter being edited based on input text and cursor position
struct CurrentlyHighlightedFilterFacade {
    let inputText: Binding<String>
    let inputSelection: Binding<TextSelection?>
    
    var currentFilter: String {
        if let range = currentFilterRange {
            String(inputText.wrappedValue[range])
        } else {
            // TODO: Should this be nil?
            ""
        }
    }
    
    var currentFilterRange: Range<String.Index>? {
        let allFilterRanges: [Range<String.Index>]
        
        do {
            allFilterRanges = try PlausibleFilterRanges.from(inputText.wrappedValue).ranges
        } catch {
            // TODO: Does this make sense?
            return entireRange
        }
        
        guard !allFilterRanges.isEmpty else {
            // TODO: Does this make sense?
            return entireRange
        }
        
        guard let selection = inputSelection.wrappedValue, case .selection(let selectionRange) = selection.indices else {
            return nil
        }
         
        return allFilterRanges.first { range in
            range.contains(selectionRange) && (
                // Empty ranges are considered to be contained by any other range, regardless of
                // their bounds values. Point TextSelections, which are used when the cursor is at
                // a location without any selection, are empty ranges, so we want to make sure that
                // we are getting the specific filter range the point selection is in. If the cursor
                // is immediately after a filter range, that is still considered the current filter.
                //
                // Filter ranges are never empty, though the compiler cannot guarantee this.
                !selectionRange.isEmpty || range.contains(selectionRange.lowerBound) || range.upperBound == selectionRange.lowerBound
            )
        }
    }
    
    private var entireRange: Range<String.Index> {
        inputText.wrappedValue.startIndex..<inputText.wrappedValue.endIndex
    }
}
