import SwiftUI

/// HIG system-color mapping for category symbols.
enum CategoryIconPalette {
    static func color(for iconName: String) -> Color {
        switch iconName {
        case "sunrise.fill": .orange
        case "takeoutbag.and.cup.and.straw.fill": .teal
        case "fork.knife": .indigo
        case "cup.and.saucer.fill": .brown
        case "gamecontroller.fill": .purple
        case "cart.fill": .green
        case "car.fill": .blue
        case "tram.fill": .cyan
        case "bag.fill": .pink
        case "gift.fill": .red
        case "book.fill": .yellow
        case "heart.fill": .pink
        case "pawprint.fill": .brown
        case "tag.fill": .mint
        default: .gray
        }
    }
}
