import SwiftData
import SwiftUI

struct TemplateDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var template: BudgetTemplate

    private static let icons = [
        "building.2.fill", "house.fill", "sofa.fill", "party.popper.fill",
        "airplane", "figure.walk", "cart.fill", "star.fill",
    ]

    var body: some View {
        List {
            Section("Template.Section.Name") {
                TextField("Template.Field.Name", text: $template.name)
            }
            Section("Template.Section.Icon") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(Self.icons, id: \.self) { icon in
                        Button {
                            template.iconName = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.title3)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(
                                    template.iconName == icon ? Color.accentColor.opacity(0.2) : Color.clear,
                                    in: .rect(cornerRadius: 10)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Section("Template.Section.Categories") {
                ForEach(template.sortedCategories) { category in
                    CategoryAmountRow(category: category)
                }
                .onDelete { indexSet in
                    let sorted = template.sortedCategories
                    for index in indexSet {
                        modelContext.delete(sorted[index])
                    }
                    try? modelContext.save()
                }
                Button("Template.AddCategory", systemImage: "plus") {
                    let category = TemplateCategory(
                        name: String(localized: "Template.NewCategory", defaultValue: "New Category"),
                        amount: 0,
                        sortOrder: (template.sortedCategories.last?.sortOrder ?? -1) + 1
                    )
                    category.template = template
                    modelContext.insert(category)
                    try? modelContext.save()
                }
            }
            Section {
                LabeledContent("Template.DailyTotal", value: template.total.currencyString)
                    .font(.headline)
            }
        }
        .navigationTitle(template.name)
        .toolbarTitleDisplayMode(.inline)
        .onDisappear { try? modelContext.save() }
    }
}
