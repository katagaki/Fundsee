import SwiftUI

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
        case "cross.case.fill": .red
        case "pills.fill": .pink
        case "stethoscope": .mint
        case "bolt.fill": .yellow
        case "drop.fill": .cyan
        case "flame.fill": .orange
        case "wifi": .blue
        case "creditcard.fill": .indigo
        case "arrow.triangle.2.circlepath": .purple
        case "house.fill": .green
        case "graduationcap.fill": .cyan
        case "tag.fill": .mint
        default: .gray
        }
    }
}
