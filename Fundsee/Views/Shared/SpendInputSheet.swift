import SwiftData
import SwiftUI

/// Records one expense against a category for a given day.
/// Offers the last three distinct amounts entered for that category as one-tap chips.
struct SpendInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let date: Date
    let categoryName: String
    let recentAmounts: [Decimal]

    @State private var amount: Decimal?
    @FocusState private var amountFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Amount", value: $amount, format: .number)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if !recentAmounts.isEmpty {
                    GlassEffectContainer {
                        HStack(spacing: 12) {
                            ForEach(recentAmounts, id: \.self) { recent in
                                Button {
                                    amount = recent
                                } label: {
                                    Text(recent.currencyString)
                                        .font(.callout.weight(.semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.glass)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle(categoryName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let amount, amount > 0 {
                            modelContext.insert(SpendEntry(dayKey: date, categoryName: categoryName, amount: amount))
                            try? modelContext.save()
                        }
                        dismiss()
                    }
                    .disabled((amount ?? 0) <= 0)
                }
            }
            .onAppear { amountFocused = true }
        }
        .presentationDetents([.medium])
    }
}

/// Overrides the template used for a specific day (today or an upcoming day).
struct TemplateOverrideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let initialDate: Date
    let allowDateChange: Bool

    @Query private var templates: [BudgetTemplate]
    @Query private var overrides: [DayOverride]
    @Query private var allSettings: [PlanSettings]

    @State private var date: Date = .now

    private var engine: BudgetEngine {
        BudgetEngine(templates: templates, overrides: overrides, entries: [], settings: allSettings.first)
    }

    var body: some View {
        NavigationStack {
            List {
                if allowDateChange {
                    DatePicker(
                        "Day",
                        selection: $date,
                        in: Calendar.current.startOfDay(for: .now)...,
                        displayedComponents: .date
                    )
                }

                Section("Template") {
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
                        Button("Remove Override", role: .destructive) {
                            removeOverride()
                        }
                    } footer: {
                        Text("Removing the override returns this day to its scheduled template.")
                    }
                }
            }
            .navigationTitle("Change Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { dismiss() }
                }
            }
            .onAppear { date = initialDate }
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
