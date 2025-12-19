//
//  Array+uniquedTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-12.
//

import Testing
@testable import MagicCardSearch

// swiftlint:disable:next type_body_length
struct ArrayUniquedTests {
    @Test("uniqued()", arguments: [
        ("empty array", [] as [String], [] as [String]),
        ("single element", ["hello"], ["hello"]),
        ("all unique", ["apple", "banana", "cherry"], ["apple", "banana", "cherry"]),
        ("all duplicates", ["apple", "apple", "apple"], ["apple"]),
        ("preserves order based on first seen", ["zebra", "apple", "banana", "apple", "zebra"], ["zebra", "apple", "banana"]),
    ])
    func uniqued(description: String, input: [String], expected: [String]) {
        #expect(input.uniqued() == expected, "\(description) failed")
    }
    
    struct TestObject {
        let id: Int
        let value: String
        let nilableValue: String?
        
        init(_ id: Int, _ value: String, _ nilableValue: String? = nil) {
            self.id = id
            self.value = value
            self.nilableValue = nilableValue
        }
    }
    
    @Test("uniqued(by:) removes duplicates based on property")
    func uniquedByNonOptionalKeyPath() {
        let objects = [
            TestObject(1, "Alice"),
            TestObject(2, "Bob"),
            TestObject(1, "Alice Duplicate"),
            TestObject(3, "Charlie"),
            TestObject(2, "Bob Duplicate"),
        ]
        
        let uniqueObjects = objects.uniqued(by: \.id)
        
        #expect(uniqueObjects.count == 3)
        #expect(uniqueObjects.map(\.value) == ["Alice", "Bob", "Charlie"])
    }
    
    @Test("uniqued(by:) with string property")
    func uniquedByStringProperty() {
        let objects = [
            TestObject(1, "Alice"),
            TestObject(2, "Bob"),
            TestObject(3, "Alice"),
            TestObject(4, "Charlie"),
        ]
        
        let uniqueObjects = objects.uniqued(by: \.value)
        
        #expect(uniqueObjects.count == 3)
        #expect(uniqueObjects.map(\.value) == ["Alice", "Bob", "Charlie"])
    }
    
    @Test("uniqued(by:) edge cases",
          arguments: [
            ("empty array", [] as [TestObject], 0),
            ("all unique", [
                TestObject(1, "Alice"),
                TestObject(2, "Bob"),
                TestObject(3, "Charlie"),
            ], 3),
            ("all duplicates", [
                TestObject(1, "Alice"),
                TestObject(1, "Alice Clone 1"),
                TestObject(1, "Alice Clone 2"),
            ], 1),
          ])
    func uniquedByEdgeCases(description: String, input: [TestObject], expectedCount: Int) {
        let result = input.uniqued(by: \.id)
        #expect(result.count == expectedCount, "\(description) failed")
        if !result.isEmpty {
            #expect(result[0].value == input[0].value, "Should keep first occurrence")
        }
    }
    
    // MARK: - Parameterized Tests for Optional KeyPath
    
    @Test("uniqued(by:) with optional property handles nil values correctly")
    func uniquedByOptionalKeyPath() {
        struct TestCase {
            let objects: [TestObject]
            let expectedCount: Int
            let expectedValues: [String]
            let description: String
        }
        
        let testCases: [TestCase] = [
            TestCase(
                objects: [
                    TestObject(1, "Alice", "alice@example.com"),
                    TestObject(2, "Bob", "bob@example.com"),
                    TestObject(3, "Charlie", "alice@example.com"),
                    TestObject(4, "Dave", nil),
                    TestObject(5, "Eve", nil),
                ],
                expectedCount: 4,
                expectedValues: ["Alice", "Bob", "Dave", "Eve"],
                description: "mixed nil and non-nil with duplicates"
            ),
            TestCase(
                objects: [
                    TestObject(1, "Alice", nil),
                    TestObject(2, "Bob", nil),
                    TestObject(3, "Charlie", nil),
                ],
                expectedCount: 3,
                expectedValues: ["Alice", "Bob", "Charlie"],
                description: "all nil values"
            ),
            TestCase(
                objects: [
                    TestObject(1, "Alice", "alice@example.com"),
                    TestObject(2, "Bob", nil),
                    TestObject(3, "Charlie", "alice@example.com"),
                    TestObject(4, "Dave", nil),
                    TestObject(5, "Eve", "eve@example.com"),
                ],
                expectedCount: 4,
                expectedValues: ["Alice", "Bob", "Dave", "Eve"],
                description: "mixed values"
            ),
        ]
        
        for testCase in testCases {
            let result = testCase.objects.uniqued(by: \.nilableValue)
            #expect(result.count == testCase.expectedCount, "\(testCase.description) count failed")
            #expect(result.map(\.value) == testCase.expectedValues, "\(testCase.description) values failed")
        }
    }
    
    @Test("uniqued(by:) with optional maintains first occurrence")
    func uniquedByOptionalMaintainsFirstOccurrence() {
        let objects = [
            TestObject(1, "Alice", "test@example.com"),
            TestObject(2, "Bob", "test@example.com"),
            TestObject(3, "Charlie", "test@example.com"),
        ]
        
        let uniqueObjects = objects.uniqued(by: \.nilableValue)
        
        #expect(uniqueObjects.count == 1)
        #expect(uniqueObjects[0].value == "Alice", "Should keep the first object with that email")
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
            
            static func == (lhs: Item, rhs: Item) -> Bool {
                lhs.id == rhs.id
            }
            
            func hash(into hasher: inout Hasher) {
                hasher.combine(id)
            }
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
    
    // MARK: - Closure-based Tests
    
    @Test("uniqued(by:) with closure removes duplicates based on computed value")
    func uniquedByNonOptionalClosure() {
        let objects = [
            TestObject(1, "Alice"),
            TestObject(2, "Bob"),
            TestObject(1, "Alice Duplicate"),
            TestObject(3, "Charlie"),
            TestObject(2, "Bob Duplicate"),
        ]
        
        let uniqueObjects = objects.uniqued { $0.id }
        
        #expect(uniqueObjects.count == 3)
        #expect(uniqueObjects.map(\.value) == ["Alice", "Bob", "Charlie"])
    }
    
    @Test("uniqued(by:) with closure can transform values")
    func uniquedByClosureWithTransformation() {
        let objects = [
            TestObject(1, "Alice"),
            TestObject(2, "bob"),
            TestObject(3, "ALICE"),
            TestObject(4, "Charlie"),
            TestObject(5, "BOB"),
        ]
        
        // Unique by case-insensitive value
        let uniqueObjects = objects.uniqued { $0.value.lowercased() }
        
        #expect(uniqueObjects.count == 3)
        #expect(uniqueObjects.map(\.value) == ["Alice", "bob", "Charlie"])
    }
    
    @Test("uniqued(by:) with closure can use computed properties")
    func uniquedByClosureWithComputedProperty() {
        struct Person {
            let firstName: String
            let lastName: String
        }
        
        let people = [
            Person(firstName: "John", lastName: "Doe"),
            Person(firstName: "Jane", lastName: "Smith"),
            Person(firstName: "John", lastName: "Doe"),
            Person(firstName: "Bob", lastName: "Jones"),
            Person(firstName: "Jane", lastName: "Smith"),
        ]
        
        // Unique by full name
        let uniquePeople = people.uniqued { "\($0.firstName) \($0.lastName)" }
        
        #expect(uniquePeople.count == 3)
        #expect(uniquePeople[0].firstName == "John")
        #expect(uniquePeople[1].firstName == "Jane")
        #expect(uniquePeople[2].firstName == "Bob")
    }
    
    @Test("uniqued(by:) with optional closure handles nil values correctly")
    func uniquedByOptionalClosure() {
        let objects = [
            TestObject(1, "Alice", "alice@example.com"),
            TestObject(2, "Bob", "bob@example.com"),
            TestObject(3, "Charlie", "alice@example.com"),
            TestObject(4, "Dave", nil),
            TestObject(5, "Eve", nil),
        ]
        
        let uniqueObjects = objects.uniqued { $0.nilableValue }
        
        #expect(uniqueObjects.count == 4)
        #expect(uniqueObjects.map(\.value) == ["Alice", "Bob", "Dave", "Eve"])
    }
    
    @Test("uniqued(by:) with optional closure can transform values")
    func uniquedByOptionalClosureWithTransformation() {
        let objects = [
            TestObject(1, "Alice", "ALICE@EXAMPLE.COM"),
            TestObject(2, "Bob", nil),
            TestObject(3, "Charlie", "alice@example.com"),
            TestObject(4, "Dave", nil),
            TestObject(5, "Eve", "eve@example.com"),
        ]
        
        // Unique by case-insensitive email
        let uniqueObjects = objects.uniqued { $0.nilableValue?.lowercased() }
        
        #expect(uniqueObjects.count == 4)
        #expect(uniqueObjects.map(\.value) == ["Alice", "Bob", "Dave", "Eve"])
    }
    
    @Test("uniqued(by:) closure vs keyPath produce same results for simple properties")
    func uniquedClosureMatchesKeyPath() {
        let objects = [
            TestObject(1, "Alice"),
            TestObject(2, "Bob"),
            TestObject(1, "Alice Duplicate"),
            TestObject(3, "Charlie"),
        ]
        
        let uniqueByKeyPath = objects.uniqued(by: \.id)
        let uniqueByClosure = objects.uniqued { $0.id }
        
        #expect(uniqueByKeyPath.map(\.id) == uniqueByClosure.map(\.id))
        #expect(uniqueByKeyPath.map(\.value) == uniqueByClosure.map(\.value))
    }
    
    @Test("uniqued(by:) with optional closure vs optional keyPath produce same results")
    func uniquedOptionalClosureMatchesOptionalKeyPath() {
        let objects = [
            TestObject(1, "Alice", "alice@example.com"),
            TestObject(2, "Bob", nil),
            TestObject(3, "Charlie", "alice@example.com"),
            TestObject(4, "Dave", nil),
        ]
        
        let uniqueByKeyPath = objects.uniqued(by: \.nilableValue)
        let uniqueByClosure = objects.uniqued { $0.nilableValue }
        
        #expect(uniqueByKeyPath.map(\.id) == uniqueByClosure.map(\.id))
        #expect(uniqueByKeyPath.map(\.value) == uniqueByClosure.map(\.value))
    }
    
    @Test("uniqued(by:) with closure handles complex transformations")
    func uniquedByClosureComplexTransformations() {
        struct Product {
            let name: String
            let price: Double
            let category: String
        }
        
        let products = [
            Product(name: "Apple", price: 1.50, category: "Fruit"),
            Product(name: "Banana", price: 0.75, category: "Fruit"),
            Product(name: "Orange", price: 1.50, category: "Fruit"),
            Product(name: "Carrot", price: 0.75, category: "Vegetable"),
        ]
        
        // Unique by price (rounded to nearest dollar) and category combination
        let uniqueProducts = products.uniqued { 
            "\(Int($0.price.rounded()))-\($0.category)"
        }
        
        #expect(uniqueProducts.count == 3)
        #expect(uniqueProducts.map(\.name) == ["Apple", "Banana", "Carrot"])
    }
    
    @Test("uniqued(by:) with closure edge cases",
          arguments: [
            ("empty array", [] as [TestObject]),
            ("single element", [TestObject(1, "Alice")]),
            ("all duplicates", [
                TestObject(1, "Alice"),
                TestObject(1, "Alice Clone 1"),
                TestObject(1, "Alice Clone 2"),
            ]),
          ])
    func uniquedByClosureEdgeCases(description: String, input: [TestObject]) {
        let resultKeyPath = input.uniqued(by: \.id)
        let resultClosure = input.uniqued { $0.id }
        
        #expect(resultKeyPath.count == resultClosure.count, "\(description) counts don't match")
        #expect(resultKeyPath.map(\.id) == resultClosure.map(\.id), "\(description) ids don't match")
    }
}
