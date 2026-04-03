import Testing
@testable import MagicCardSearch

struct StringAsVulgarFractionTests {
    @Test("asVulgarFraction", arguments: [
        ("0.5", "½"),
        ("3.5", "3½"),
        ("1.5", "1½"),
        ("1", "1"),
        ("0", "0"),
        ("*", "*"),
        ("1.0", "1.0"),
        ("", ""),
        (" 0.5", " 0.5"),
        ("0.5 ", "0.5 "),
        (" 3.5 ", " 3.5 "),
    ])
    func asVulgarFraction(input: String, expected: String) {
        #expect(input.asVulgarFraction == expected)
    }
}
