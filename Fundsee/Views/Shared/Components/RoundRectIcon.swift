import SwiftUI

struct RoundRectIcon: View {
    let systemImage: String
    var color: Color = .accentColor

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color.gradient, in: .rect(cornerRadius: 7))
    }
}
