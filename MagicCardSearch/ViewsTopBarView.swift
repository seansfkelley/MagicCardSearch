//
//  TopBarView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import SwiftUI

struct TopBarView: View {
    let onDisplayTap: () -> Void
    let onSettingsTap: () -> Void
    let badgeCount: Int
    
    var body: some View {
        HStack {
            Button(action: onDisplayTap) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.title2)
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                    
                    if badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Circle().fill(.red))
                            .offset(x: 8, y: 4)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.title)
                .foregroundStyle(.tint)
            
            Spacer()
            
            Button(action: onSettingsTap) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}
