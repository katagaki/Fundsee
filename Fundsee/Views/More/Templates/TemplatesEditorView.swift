import SwiftData
import SwiftUI

struct TemplatesEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetTemplate.createdAt) private var templates: [BudgetTemplate]

    var body: some View {
        List {
            ForEach(templates) { template in
                NavigationLink {
                    TemplateDetailView(template: template)
                } label: {
                    HStack {
                        Label {
                            Text(template.name)
                        } icon: {
                            RoundRectIcon(systemImage: template.iconName)
                        }
                        Spacer()
                        Text(template.total.currencyString)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    modelContext.delete(templates[index])
                }
                try? modelContext.save()
            }
        }
        .navigationTitle("Templates.Title")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Templates.Add", systemImage: "plus") {
                    let template = BudgetTemplate(name: String(localized: "Templates.NewTemplate", defaultValue: "New Plan"), iconName: AppSymbol.budgetTemplate)
                    modelContext.insert(template)
                    for (index, name) in DefaultData.categoryNames.enumerated() {
                        let category = TemplateCategory(name: name, amount: 0, sortOrder: index, iconName: DefaultData.categoryIcons[index])
                        category.template = template
                        modelContext.insert(category)
                    }
                    try? modelContext.save()
                }
            }
        }
    }
}
