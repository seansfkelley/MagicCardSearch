import Testing
import Foundation
import ScryfallKit
@testable import MagicCardSearch

private func makeSet(
    code: String,
    name: String,
    block: String? = nil,
    setType: MTGSet.Kind = .expansion
) -> MTGSet {
    MTGSet(
        id: UUID(),
        code: code,
        name: name,
        setType: setType,
        block: block,
        cardCount: 0,
        digital: false,
        foilOnly: false,
        nonfoilOnly: false,
        scryfallUri: "",
        uri: "",
        iconSvgUri: "",
        searchUri: ""
    )
}

@Suite
struct EnumerationCatalogDataTests {
    // MARK: - artist

    @Test("artist returns nil when artistNames catalog is absent")
    func artistNil() {
        let data = EnumerationCatalogData(catalogs: [:], sets: nil, artTags: nil, oracleTags: nil)
        #expect(data.artist == nil)
    }

    @Test("artist returns artistNames catalog values")
    func artistValues() {
        let data = EnumerationCatalogData(
            catalogs: [.artistNames: ["John Avon", "Rebecca Guay"]],
            sets: nil,
            artTags: nil,
            oracleTags: nil
        )
        #expect(data.artist == ["John Avon", "Rebecca Guay"])
    }

    // MARK: - watermark

    @Test("watermark returns nil when watermarks catalog is absent")
    func watermarkNil() {
        let data = EnumerationCatalogData(catalogs: [:], sets: nil, artTags: nil, oracleTags: nil)
        #expect(data.watermark == nil)
    }

    @Test("watermark returns watermarks catalog values")
    func watermarkValues() {
        let data = EnumerationCatalogData(
            catalogs: [.watermarks: ["urza", "phyrexian"]],
            sets: nil,
            artTags: nil,
            oracleTags: nil
        )
        #expect(data.watermark == ["urza", "phyrexian"])
    }

    // MARK: - art

    @Test("art returns the artTags parameter")
    func artValues() {
        let data = EnumerationCatalogData(catalogs: [:], sets: nil, artTags: ["fog", "dragon"], oracleTags: nil)
        #expect(data.art == ["fog", "dragon"])
    }

    @Test("art returns nil when artTags is nil")
    func artNil() {
        let data = EnumerationCatalogData(catalogs: [:], sets: nil, artTags: nil, oracleTags: nil)
        #expect(data.art == nil)
    }

    // MARK: - function

    @Test("function returns the oracleTags parameter")
    func functionValues() {
        let data = EnumerationCatalogData(catalogs: [:], sets: nil, artTags: nil, oracleTags: ["draw", "ramp"])
        #expect(data.function == ["draw", "ramp"])
    }

    @Test("function returns nil when oracleTags is nil")
    func functionNil() {
        let data = EnumerationCatalogData(catalogs: [:], sets: nil, artTags: nil, oracleTags: nil)
        #expect(data.function == nil)
    }

    // MARK: - keyword

    @Test("keyword returns nil when either keywordAbilities or abilityWords catalog is absent")
    func keywordNilWhenMissing() {
        let onlyAbilities = EnumerationCatalogData(
            catalogs: [.keywordAbilities: ["Flying"]],
            sets: nil,
            artTags: nil,
            oracleTags: nil
        )
        #expect(onlyAbilities.keyword == nil)

        let onlyWords = EnumerationCatalogData(
            catalogs: [.abilityWords: ["Landfall"]],
            sets: nil,
            artTags: nil,
            oracleTags: nil
        )
        #expect(onlyWords.keyword == nil)
    }

    @Test("keyword combines keywordAbilities and abilityWords, lowercased")
    func keywordCombined() {
        let data = EnumerationCatalogData(
            catalogs: [
                .keywordAbilities: ["Flying", "Trample"],
                .abilityWords: ["Landfall"],
            ],
            sets: nil,
            artTags: nil,
            oracleTags: nil
        )
        #expect(data.keyword == ["flying", "trample", "landfall"])
    }

    // MARK: - type

    @Test("type returns nil when any required catalog is absent")
    func typeNilWhenMissing() {
        // Provide all but one required catalog
        let catalogs: [Catalog.`Type`: [String]] = [
            .supertypes: ["Legendary"],
            .cardTypes: ["Creature"],
            .artifactTypes: ["Equipment"],
            .battleTypes: [],
            .creatureTypes: ["Human"],
            .enchantmentTypes: ["Aura"],
            .landTypes: ["Forest"],
            .planeswalkerTypes: ["Jace"],
            // spellTypes intentionally omitted
        ]
        let data = EnumerationCatalogData(catalogs: catalogs, sets: nil, artTags: nil, oracleTags: nil)
        #expect(data.type == nil)
    }

    @Test("type combines all type catalogs")
    func typeCombined() throws {
        let catalogs: [Catalog.`Type`: [String]] = [
            .supertypes: ["Legendary"],
            .cardTypes: ["Creature"],
            .artifactTypes: ["Equipment"],
            .battleTypes: [],
            .creatureTypes: ["Human"],
            .enchantmentTypes: ["Aura"],
            .landTypes: ["Forest"],
            .planeswalkerTypes: ["Jace"],
            .spellTypes: ["Arcane"],
        ]
        let data = EnumerationCatalogData(catalogs: catalogs, sets: nil, artTags: nil, oracleTags: nil)
        let result = try #require(data.type)
        #expect(result.contains("Legendary"))
        #expect(result.contains("Creature"))
        #expect(result.contains("Human"))
        #expect(result.contains("Arcane"))
    }

    // MARK: - set

    @Test("set returns nil when sets is nil")
    func setNil() {
        let data = EnumerationCatalogData(catalogs: [:], sets: nil, artTags: nil, oracleTags: nil)
        #expect(data.set == nil)
    }

    @Test("set includes both uppercased code and name for each set")
    func setIncludesCodeAndName() throws {
        let ktk = makeSet(code: "ktk", name: "Khans of Tarkir")
        let data = EnumerationCatalogData(
            catalogs: [:],
            sets: [SetCode("ktk"): ktk],
            artTags: nil,
            oracleTags: nil
        )
        let result = try #require(data.set)
        #expect(result.contains("KTK"))
        #expect(result.contains("Khans of Tarkir"))
    }

    @Test("set strips non-alphanumeric characters from names")
    func setStripsSpecialChars() throws {
        let set = makeSet(code: "afr", name: "Adventures in the Forgotten Realms: D&D")
        let data = EnumerationCatalogData(
            catalogs: [:],
            sets: [SetCode("afr"): set],
            artTags: nil,
            oracleTags: nil
        )
        let result = try #require(data.set)
        #expect(result.contains("Adventures in the Forgotten Realms DD"))
    }

    @Test("set excludes token sets")
    func setExcludesTokens() {
        let tokenSet = makeSet(code: "tktk", name: "Khans of Tarkir Tokens", setType: .token)
        let data = EnumerationCatalogData(
            catalogs: [:],
            sets: [SetCode("tktk"): tokenSet],
            artTags: nil,
            oracleTags: nil
        )
        #expect(data.set!.isEmpty)
    }

    @Test("set excludes promo sets")
    func setExcludesPromos() {
        let promoSet = makeSet(code: "pktk", name: "Khans of Tarkir Promos", setType: .promo)
        let data = EnumerationCatalogData(
            catalogs: [:],
            sets: [SetCode("pktk"): promoSet],
            artTags: nil,
            oracleTags: nil
        )
        #expect(data.set!.isEmpty)
    }

    @Test("set excludes memorabilia sets")
    func setExcludesMemorabillia() {
        let memorabiliaSet = makeSet(code: "med", name: "Media Inserts", setType: .memorabilia)
        let data = EnumerationCatalogData(
            catalogs: [:],
            sets: [SetCode("med"): memorabiliaSet],
            artTags: nil,
            oracleTags: nil
        )
        #expect(data.set!.isEmpty)
    }

    // MARK: - block

    @Test("block returns nil when sets is nil")
    func blockNil() {
        let data = EnumerationCatalogData(catalogs: [:], sets: nil, artTags: nil, oracleTags: nil)
        #expect(data.block == nil)
    }

    @Test("block returns unique block names from sets, stripped of special chars")
    func blockValues() throws {
        let ktk = makeSet(code: "ktk", name: "Khans of Tarkir", block: "Khans of Tarkir")
        let frf = makeSet(code: "frf", name: "Fate Reforged", block: "Khans of Tarkir")
        let data = EnumerationCatalogData(
            catalogs: [:],
            sets: [SetCode("ktk"): ktk, SetCode("frf"): frf],
            artTags: nil,
            oracleTags: nil
        )
        let result = try #require(data.block)
        #expect(result == ["Khans of Tarkir"])
    }

    @Test("block omits sets without a block")
    func blockOmitsNilBlock() {
        let set = makeSet(code: "lea", name: "Limited Edition Alpha")
        let data = EnumerationCatalogData(
            catalogs: [:],
            sets: [SetCode("lea"): set],
            artTags: nil,
            oracleTags: nil
        )
        #expect(data.block!.isEmpty)
    }

    // MARK: - subscript

    @Test("subscript routes to the correct computed property by filter type name")
    func subscriptRouting() {
        let data = EnumerationCatalogData(
            catalogs: [
                .artistNames: ["Terese Nielsen"],
                .watermarks: ["urza"],
            ],
            sets: nil,
            artTags: ["fog"],
            oracleTags: ["ramp"]
        )
        #expect(data[ScryfallFilterType("artist")]?.first == "Terese Nielsen")
        #expect(data[ScryfallFilterType("watermark")]?.first == "urza")
        #expect(data[ScryfallFilterType("art")]?.first == "fog")
        #expect(data[ScryfallFilterType("function")]?.first == "ramp")
        #expect(data[ScryfallFilterType("oracle")] == nil)
        #expect(data[ScryfallFilterType("flavor")] == nil)
        #expect(data[ScryfallFilterType("name")] == nil)
    }
}
