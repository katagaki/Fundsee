import SwiftData
import SwiftUI

struct SpendInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let date: Date
    let categoryName: String
    let recentAmounts: [Decimal]
    var scope: SpendScope = .day
    var period: DateInterval?

    @Query(sort: \SpendEntry.timestamp, order: .reverse) private var allEntries: [SpendEntry]

    @State private var amount: Decimal?
    @FocusState private var amountFocused: Bool

    private var recordedEntries: [SpendEntry] {
        allEntries.filter { entry in
            guard entry.categoryName == categoryName, entry.scope == scope else { return false }
            guard let period else { return Calendar.current.isDate(entry.dayKey, inSameDayAs: date) }
            return period.contains(entry.dayKey) && entry.dayKey < period.end
        }
    }

    private var recordedTitle: String {
        if period != nil {
            return String(localized: "SpendInput.Recorded", defaultValue: "Recorded")
        }
        if date.isToday {
            return String(localized: "Common.TodaysSpend", defaultValue: "Today's Spend")
        }
        let day = date.formatted(.dateTime.month(.abbreviated).day())
        return String(localized: "Common.SpendOnDate", defaultValue: "Spend on \(day)")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    inputArea
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if !recordedEntries.isEmpty {
                    Section(recordedTitle) {
                        ForEach(recordedEntries) { entry in
                            HStack {
                                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(entry.amount.currencyString)
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Common.Delete", systemImage: "trash", role: .destructive) {
                                    modelContext.delete(entry)
                                    try? modelContext.save()
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(categoryName)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("SpendInput.Add") {
                        if let amount, amount > 0 {
                            modelContext.insert(SpendEntry(dayKey: date, categoryName: categoryName, amount: amount, scope: scope))
                            try? modelContext.save()
                        }
                        dismiss()
                    }
                    .disabled((amount ?? 0) <= 0)
                }
            }
            .onAppear { amountFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private var inputArea: some View {
        VStack(spacing: 24) {
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Common.Amount", value: $amount, format: .number)
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
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}
