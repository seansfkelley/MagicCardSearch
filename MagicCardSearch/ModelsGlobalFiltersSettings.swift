//
//  GlobalFiltersSettings.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import Foundation

struct GlobalFiltersSettings: Codable {
    var isEnabled: Bool
    var filters: [SearchFilter]
    
    init(isEnabled: Bool = true, filters: [SearchFilter] = []) {
        self.isEnabled = isEnabled
        self.filters = filters
    }
    
    // MARK: - Persistence
    
    private static let userDefaultsKey = "globalFiltersSettings"
    
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.userDefaultsKey)
        }
    }
    
    static func load() -> GlobalFiltersSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let settings = try? JSONDecoder().decode(GlobalFiltersSettings.self, from: data) else {
            return GlobalFiltersSettings() // Return default if not found
        }
        return settings
    }
}
