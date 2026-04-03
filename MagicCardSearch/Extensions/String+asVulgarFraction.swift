import Foundation

extension String {
    var asVulgarFraction: String {
        guard let match = wholeMatch(of: /(\d+)\.5/),
              let intPart = Int(match.1) else { return self }
        return intPart == 0 ? "½" : "\(intPart)½"
    }
}
