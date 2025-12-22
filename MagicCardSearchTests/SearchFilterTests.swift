import Testing
@testable import MagicCardSearch

@Suite("SearchFilter Tests")
struct SearchFilterTests {
    @Test(
        "description and suggestedEditingRange",
        arguments: [
            // Simple name without spaces
            (SearchFilter(.name("lightning", false)), "lightning", "lightning"),
            // Name with spaces (quoted)
            (SearchFilter(.name("lightning bolt", false)), "\"lightning bolt\"", "lightning bolt"),
            // Exact name without spaces
            (SearchFilter(.name("lightning", true)), "!lightning", "lightning"),
            // Exact name with spaces (quoted)
            (SearchFilter(.name("lightning bolt", true)), "!\"lightning bolt\"", "lightning bolt"),
            
            // Negated simple name
            (SearchFilter(true, .name("lightning", false)), "-lightning", "lightning"),
            // Negated name with spaces
            (SearchFilter(true, .name("lightning bolt", false)), "-\"lightning bolt\"", "lightning bolt"),
            // Negated exact name
            (SearchFilter(true, .name("lightning", true)), "-!lightning", "lightning"),
            
            // Key-value without spaces
            (SearchFilter(.keyValue("color", .equal, "red")), "color=red", "red"),
            // Key-value with spaces (quoted)
            (SearchFilter(.keyValue("type", .including, "legendary creature")), "type:\"legendary creature\"", "legendary creature"),
            // Key-value with different comparison
            (SearchFilter(.keyValue("power", .greaterThan, "5")), "power>5", "5"),
            
            // Negated key-value
            (SearchFilter(true, .keyValue("color", .equal, "red")), "-color=red", "red"),
            (SearchFilter(true, .keyValue("type", .including, "legendary creature")), "-type:\"legendary creature\"", "legendary creature"),
            
            // Regex filters
            (SearchFilter(.regex("oracle", .including, "flying")), "oracle:/flying/", "flying"),
            (SearchFilter(.regex("name", .equal, "^lightning")), "name=/^lightning/", "^lightning"),
            
            // Negated regex
            (SearchFilter(true, .regex("oracle", .including, "flying")), "-oracle:/flying/", "flying"),
            
            // Parenthesized content
            (SearchFilter(.parenthesized("color=red or color=blue")), "(color=red or color=blue)", "color=red or color=blue"),
            (SearchFilter(true, .parenthesized("color=red or color=blue")), "-(color=red or color=blue)", "color=red or color=blue"),
        ]
    )
    func descriptionAndSuggestedEditingRange(
        filter: SearchFilter,
        expectedDescription: String,
        expectedEditingContent: String
    ) {
        // Test description
        #expect(filter.description == expectedDescription)
        
        // Test suggestedEditingRange
        let description = filter.description
        let editingRange = filter.suggestedEditingRange
        let extractedContent = String(description[editingRange])
        
        #expect(extractedContent == expectedEditingContent)
    }
}
