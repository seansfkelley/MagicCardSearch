//
//  Array+uniquedTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-12.
//

import Testing
@testable import MagicCardSearch

@Suite("Array uniqued() extension tests")
struct ArrayUniquedTests {
    // MARK: - Test Models
    
    struct Person {
        let id: Int
        let name: String
        let email: String?
    }
    
    // MARK: - Parameterized Tests for Hashable Elements
    
    @Test("uniqued() removes duplicates and preserves order",
          arguments: [
            ([1, 2, 3, 2, 4, 1, 5, 3], [1, 2, 3, 4, 5]),
            (["apple", "banana", "apple", "cherry", "banana", "date"], ["apple", "banana", "cherry", "date"]),
            (["zebra", "apple", "banana", "apple", "zebra"], ["zebra", "apple", "banana"]),
            ([5, 2, 8, 2, 5, 1, 8, 3], [5, 2, 8, 1, 3]),
          ] as [([AnyHashable], [AnyHashable])])
    func uniquedRemovesDuplicates(input: [AnyHashable], expected: [AnyHashable]) {
        if let intInput = input as? [Int], let intExpected = expected as? [Int] {
            #expect(intInput.uniqued() == intExpected)
        } else if let stringInput = input as? [String], let stringExpected = expected as? [String] {
            #expect(stringInput.uniqued() == stringExpected)
        }
    }
    
    @Test("uniqued() handles edge cases",
          arguments: [
            ("empty array", [] as [String], [] as [String]),
            ("single element", ["hello"], ["hello"]),
            ("all unique", ["apple", "banana", "cherry"], ["apple", "banana", "cherry"]),
            ("all duplicates", ["apple", "apple", "apple"], ["apple"]),
          ])
    func uniquedEdgeCases(description: String, input: [String], expected: [String]) {
        #expect(input.uniqued() == expected, "\(description) failed")
    }
    
    // MARK: - Parameterized Tests for Non-Optional KeyPath
    
    @Test("uniqued(by:) removes duplicates based on property")
    func uniquedByNonOptionalKeyPath() {
        let people = [
            Person(id: 1, name: "Alice", email: "alice@example.com"),
            Person(id: 2, name: "Bob", email: "bob@example.com"),
            Person(id: 1, name: "Alice Duplicate", email: "alice2@example.com"),
            Person(id: 3, name: "Charlie", email: "charlie@example.com"),
            Person(id: 2, name: "Bob Duplicate", email: "bob2@example.com"),
        ]
        
        let uniquePeople = people.uniqued(by: \.id)
        
        #expect(uniquePeople.count == 3)
        #expect(uniquePeople.map(\.name) == ["Alice", "Bob", "Charlie"])
    }
    
    @Test("uniqued(by:) with string property")
    func uniquedByStringProperty() {
        let people = [
            Person(id: 1, name: "Alice", email: nil),
            Person(id: 2, name: "Bob", email: nil),
            Person(id: 3, name: "Alice", email: nil),
            Person(id: 4, name: "Charlie", email: nil),
        ]
        
        let uniquePeople = people.uniqued(by: \.name)
        
        #expect(uniquePeople.count == 3)
        #expect(uniquePeople.map(\.name) == ["Alice", "Bob", "Charlie"])
    }
    
    @Test("uniqued(by:) edge cases",
          arguments: [
            ("empty array", [] as [Person], 0),
            ("all unique", [
                Person(id: 1, name: "Alice", email: nil),
                Person(id: 2, name: "Bob", email: nil),
                Person(id: 3, name: "Charlie", email: nil),
            ], 3),
            ("all duplicates", [
                Person(id: 1, name: "Alice", email: nil),
                Person(id: 1, name: "Alice Clone 1", email: nil),
                Person(id: 1, name: "Alice Clone 2", email: nil),
            ], 1),
          ])
    func uniquedByEdgeCases(description: String, input: [Person], expectedCount: Int) {
        let result = input.uniqued(by: \.id)
        #expect(result.count == expectedCount, "\(description) failed")
        if !result.isEmpty {
            #expect(result[0].name == input[0].name, "Should keep first occurrence")
        }
    }
    
    // MARK: - Parameterized Tests for Optional KeyPath
    
    @Test("uniqued(by:) with optional property handles nil values correctly")
    func uniquedByOptionalKeyPath() {
        struct TestCase {
            let people: [Person]
            let expectedCount: Int
            let expectedNames: [String]
            let description: String
        }
        
        let testCases: [TestCase] = [
            TestCase(
                people: [
                    Person(id: 1, name: "Alice", email: "alice@example.com"),
                    Person(id: 2, name: "Bob", email: "bob@example.com"),
                    Person(id: 3, name: "Charlie", email: "alice@example.com"),
                    Person(id: 4, name: "Dave", email: nil),
                    Person(id: 5, name: "Eve", email: nil),
                ],
                expectedCount: 4,
                expectedNames: ["Alice", "Bob", "Dave", "Eve"],
                description: "mixed nil and non-nil with duplicates"
            ),
            TestCase(
                people: [
                    Person(id: 1, name: "Alice", email: nil),
                    Person(id: 2, name: "Bob", email: nil),
                    Person(id: 3, name: "Charlie", email: nil),
                ],
                expectedCount: 3,
                expectedNames: ["Alice", "Bob", "Charlie"],
                description: "all nil values"
            ),
            TestCase(
                people: [
                    Person(id: 1, name: "Alice", email: "alice@example.com"),
                    Person(id: 2, name: "Bob", email: nil),
                    Person(id: 3, name: "Charlie", email: "alice@example.com"),
                    Person(id: 4, name: "Dave", email: nil),
                    Person(id: 5, name: "Eve", email: "eve@example.com"),
                ],
                expectedCount: 4,
                expectedNames: ["Alice", "Bob", "Dave", "Eve"],
                description: "mixed values"
            ),
        ]
        
        for testCase in testCases {
            let result = testCase.people.uniqued(by: \.email)
            #expect(result.count == testCase.expectedCount, "\(testCase.description) count failed")
            #expect(result.map(\.name) == testCase.expectedNames, "\(testCase.description) names failed")
        }
    }
    
    @Test("uniqued(by:) with optional maintains first occurrence")
    func uniquedByOptionalMaintainsFirstOccurrence() {
        let people = [
            Person(id: 1, name: "Alice", email: "test@example.com"),
            Person(id: 2, name: "Bob", email: "test@example.com"),
            Person(id: 3, name: "Charlie", email: "test@example.com"),
        ]
        
        let uniquePeople = people.uniqued(by: \.email)
        
        #expect(uniquePeople.count == 1)
        #expect(uniquePeople[0].name == "Alice", "Should keep the first person with that email")
    }
    
    // MARK: - Complex Structures and Performance
    
    @Test("uniqued(by:) works with complex nested structures")
    func uniquedByWorksWithNestedStructures() {
        struct Article {
            let id: String
            let title: String
        }
        
        let articles = [
            Article(id: "abc", title: "First"),
            Article(id: "def", title: "Second"),
            Article(id: "abc", title: "First Duplicate"),
            Article(id: "ghi", title: "Third"),
        ]
        
        let uniqueArticles = articles.uniqued(by: \.id)
        
        #expect(uniqueArticles.count == 3)
        #expect(uniqueArticles.map(\.title) == ["First", "Second", "Third"])
    }
    
    @Test("uniqued() maintains first occurrence of duplicates")
    func uniquedMaintainsFirstOccurrence() {
        struct Item: Hashable {
            let id: Int
            let value: String
        }
        
        let items = [
            Item(id: 1, value: "first"),
            Item(id: 1, value: "second"),
            Item(id: 1, value: "third"),
        ]
        
        let uniqueItems = items.uniqued()
        
        #expect(uniqueItems.count == 1)
        #expect(uniqueItems[0].value == "first", "Should keep the first occurrence")
    }
    
    @Test("uniqued() works with large arrays", arguments: [100, 1000, 5000])
    func uniquedWorksWithLargeArrays(repetitions: Int) {
        let largeArray = Array(repeating: [1, 2, 3, 4, 5], count: repetitions).flatMap { $0 }
        let uniqueNumbers = largeArray.uniqued()
        
        #expect(uniqueNumbers == [1, 2, 3, 4, 5])
    }
}
