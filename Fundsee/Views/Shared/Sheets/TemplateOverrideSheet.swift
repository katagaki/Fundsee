import SwiftData
import SwiftUI

struct TemplateOverrideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let initialDate: Date

    @Query private var templates: [BudgetTemplate]
    @Query private var overrides: [DayOverride]
    @Query private var allSettings: [PlanSettings]

    private var date: Date { initialDate }

    private var engine: BudgetEngine {
        BudgetEngine(templates: templates, overrides: overrides, entries: [], settings: allSettings.first)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("TemplateOverride.Section.Template") {
                    ForEach(templates.sorted(by: { $0.createdAt < $1.createdAt })) { template in
                        Button {
                            apply(template)
                        } label: {
                            HStack {
                                Label(template.name, systemImage: template.iconName)
                                Spacer()
                                Text(template.total.currencyString)
                                    .foregroundStyle(.secondary)
                                if engine.template(for: date) === template {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }

                if engine.override(for: date) != nil {
                    Section {
                        Button("TemplateOverride.Remove", role: .destructive) {
                            removeOverride()
                        }
                    } footer: {
                        Text("TemplateOverride.Remove.Footer")
                    }
                }
            }
            .navigationTitle("Common.ChangeTemplate")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func apply(_ template: BudgetTemplate) {
        removeOverride()
        modelContext.insert(DayOverride(dayKey: date, template: template))
        try? modelContext.save()
        dismiss()
    }

    private func removeOverride() {
        for override in overrides where Calendar.current.isDate(override.dayKey, inSameDayAs: date) {
            modelContext.delete(override)
        }
        try? modelContext.save()
    }
}
