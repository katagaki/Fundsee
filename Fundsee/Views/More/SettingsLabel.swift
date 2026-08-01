import SwiftUI

/// Settings-app-style row label: white symbol on a colored rounded rectangle.
struct SettingsLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    let color: Color

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color.gradient, in: .rect(cornerRadius: 7))
        }
    }
}
