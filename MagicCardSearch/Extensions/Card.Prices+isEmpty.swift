import ScryfallKit

extension Card.Prices {
    var isEmpty: Bool {
        usd.isEmpty && usdFoil.isEmpty && usdEtched.isEmpty &&
        eur.isEmpty && eurFoil.isEmpty && eurEtched.isEmpty &&
        tix.isEmpty
    }
}

private extension Optional where Wrapped == String {
    var isEmpty: Bool { flatMap { $0.isEmpty } ?? true }
}
