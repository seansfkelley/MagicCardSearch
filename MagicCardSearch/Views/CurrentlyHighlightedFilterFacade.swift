//
//  CurrentFilterTracker.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-22.
//

import SwiftUI

/// Tracks the current filter being edited based on input text and cursor position
struct CurrentlyHighlightedFilterFacade {
    // MARK: - Input Properties (read by this object)
    
    let inputText: Binding<String>
    let inputSelection: Binding<TextSelection?>
    
    // MARK: - Output Properties (exposed by this object)
    
    var currentFilter: String {
        inputText.wrappedValue
    }
    
    var currentFilterRange: Range<String.Index> {
        let text = inputText.wrappedValue
        return text.startIndex..<text.endIndex
    }
}
