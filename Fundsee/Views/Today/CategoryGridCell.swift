import SwiftUI

/// Category card: colored gradient tile whose background fills as the
/// budget is used — the spent fraction is solid, the rest translucent.
struct CategoryGridCell: View {
    @Environment(\.colorScheme) private var colorScheme

    let category: TemplateCategory
    let used: Decimal

    /// Light mode keeps the tiles pale, so white text washes out on them: the
    /// label takes a darkened version of the category color instead.
    private var labelColor: Color {
        colorScheme == .light ? category.iconColor.mix(with: .black, by: 0.55) : .white
    }

    var body: some View {
        let over = used > category.amount
        let fraction = category.amount > 0
            ? min(1, used.doubleValue / category.amount.doubleValue)
            : (used > 0 ? 1 : 0)
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: category.iconName)
                .font(.system(size: 20))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(labelColor)
                .frame(height: 26)
            Text(category.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(labelColor.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(used.compactCurrencyString)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(labelColor)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(category.iconColor.gradient)
                        .opacity(colorScheme == .light ? 0.22 : 0.3)
                    Rectangle()
                        .fill(category.iconColor.gradient)
                        .opacity(colorScheme == .light ? 0.5 : 1)
                        .frame(width: proxy.size.width * fraction)

                    if over {
                        RadialGradient(
                            colors: [Color.red.opacity(0.85), .clear],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: max(proxy.size.width, proxy.size.height) * 0.75
                        )
                    }
                }
            }
        }
        .clipShape(.rect(cornerRadius: 22))
        .shadow(
            color: colorScheme == .light ? category.iconColor.opacity(0.35) : .clear,
            radius: 6, y: 3
        )
        .contentShape(.rect)
    }
}
