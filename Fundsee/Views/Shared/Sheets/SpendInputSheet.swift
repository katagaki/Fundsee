import SwiftData
import SwiftUI

/// Records one expense against a category for a given day, and lists what is
/// already recorded against that category so it can be corrected on the spot.
/// Offers the last three distinct amounts entered for that category as one-tap chips.
struct SpendInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let date: Date
    let categoryName: String
    let recentAmounts: [Decimal]

    @Query(sort: \SpendEntry.timestamp, order: .reverse) private var allEntries: [SpendEntry]

    @State private var amount: Decimal?
    @FocusState private var amountFocused: Bool

    private var recordedEntries: [SpendEntry] {
        allEntries.filter {
            $0.categoryName == categoryName && Calendar.current.isDate($0.dayKey, inSameDayAs: date)
        }
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
                    Section("Common.Recorded") {
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
