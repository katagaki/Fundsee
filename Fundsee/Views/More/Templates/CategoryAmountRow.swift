import SwiftUI

struct CategoryAmountRow: View {
    @Bindable var category: TemplateCategory

    private static let iconRows: [[String]] = stride(from: 0, to: AppSymbol.categoryIcons.count, by: 5).map {
        Array(AppSymbol.categoryIcons[$0..<min($0 + 5, AppSymbol.categoryIcons.count)])
    }

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(Array(Self.iconRows.enumerated()), id: \.offset) { index, row in
                    Picker(selection: $category.iconName) {
                        ForEach(row, id: \.self) { icon in
                            Image(systemName: icon)
                                .tag(icon)
                        }
                    } label: {
                        if index == 0 {
                            Text("Template.Section.Icon")
                        }
                    }
                    .pickerStyle(.palette)
                }
            } label: {
                RoundRectIcon(systemImage: category.iconName, color: category.iconColor)
            }
            TextField("Template.Field.Category", text: $category.name)
            Spacer()
            TextField("Common.Amount", value: $category.amount, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                .foregroundStyle(.secondary)
        }
    }
}
