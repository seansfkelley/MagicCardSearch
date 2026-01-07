import SwiftUI

/// Tracks the current filter being edited based on input text and cursor position
struct CurrentlyHighlightedFilterFacade {
    let inputText: String
    let inputSelection: Range<String.Index>

    var text: String {
        if let range = range {
            String(inputText[range])
        } else {
            // TODO: Should this be nil?
            ""
        }
    }
    
    var range: Range<String.Index>? {
        let allFilterRanges = PlausibleFilterRanges.from(inputText).ranges

        guard !allFilterRanges.isEmpty else {
            // This or nil?
            return inputText.range
        }

        return allFilterRanges.first { range in
            range.contains(inputSelection) && (
                // Empty ranges are considered to be contained by any other range, regardless of
                // their bounds values. Point TextSelections, which are used when the cursor is at
                // a location without any selection, are empty ranges, so we want to make sure that
                // we are getting the specific filter range the point selection is in. If the cursor
                // is immediately after a filter range, that is still considered the current filter.
                //
                // Filter ranges are never empty, though the compiler cannot guarantee this.
                !inputSelection.isEmpty || range.contains(inputSelection.lowerBound) || range.upperBound == inputSelection.lowerBound
            )
        }
    }
}
