import SwiftUI

extension View {
    func fundseeCard() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(.background.secondary, in: .rect(cornerRadius: 24))
    }
}
