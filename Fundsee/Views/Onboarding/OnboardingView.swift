import SwiftData
import SwiftUI

/// Guided first-run setup styled after Apple's own onboarding screens:
/// a large centered title, feature rows, and a prominent bottom button.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var step = UserDefaults.standard.integer(forKey: "onboardingStep")
    private let stepCount = 5

    var body: some View {
        NavigationStack {
            ZStack {
                switch step {
                case 0: welcomeStep
                case 1: OnboardingTemplatesStep()
                case 2: weekPlanStep
                case 3: budgetsAndBehaviorStep
                default: notificationsStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) { bottomBar }
            .toolbar {
                if step > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.snappy) { step -= 1 }
                        } label: {
                            Image(systemName: "chevron.backward")
                        }
                        .accessibilityLabel("Back")
                    }
                }
            }
            .task {
                DefaultData.seedIfNeeded(context: modelContext)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 16) {
            if step == 0 {
                Text("Your budgets stay private, synced securely with iCloud.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Button {
                if step == stepCount - 1 {
                    hasCompletedOnboarding = true
                } else {
                    withAnimation(.snappy) { step += 1 }
                }
            } label: {
                Text(step == stepCount - 1 ? "Start Budgeting" : "Continue")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
        }
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    // MARK: - Step 1: Welcome (feature list, "What's New" style)

    private var welcomeStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 16) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.white, Color.accentColor)
                        .frame(width: 108, height: 108)
                        .background(Color.accentColor.gradient, in: .rect(cornerRadius: 24))
                        .shadow(color: Color.accentColor.opacity(0.35), radius: 18, y: 8)
                    Text("Welcome to Fundsee")
                        .font(.system(size: 34, weight: .bold))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
                .padding(.bottom, 40)

                VStack(alignment: .leading, spacing: 28) {
                    featureRow(
                        icon: AppSymbol.budgetTemplate,
                        title: "Budget Templates",
                        subtitle: "Set up budgets for the kinds of days you have, like office days, home days, and days off."
                    )
                    featureRow(
                        icon: "calendar.badge.clock",
                        title: "Plan Your Week",
                        subtitle: "Assign a template to each weekday and Fundsee works out your week and month."
                    )
                    featureRow(
                        icon: "chart.bar.xaxis",
                        title: "See Where You Stand",
                        subtitle: "Visual daily, weekly, monthly, and yearly views show what's spent and what's left."
                    )
                }
                .padding(.horizontal, 36)
            }
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(Color.accentColor)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Later steps

    private var weekPlanStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                icon: "calendar.badge.clock",
                title: "Plan Your Week",
                subtitle: "Assign a template to each weekday. You can always override individual days later."
            )
            WeekPlanEditorView()
                .scrollContentBackground(.hidden)
        }
    }

    private var budgetsAndBehaviorStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                icon: "basket.fill",
                title: "Extras & Leftovers",
                subtitle: "Optional weekly and monthly overall budgets, and what happens to unused budget."
            )
            List {
                OnboardingOverallBudgetsSection()
                OnboardingCarryoverSection()
            }
            .scrollContentBackground(.hidden)
        }
    }

    private var notificationsStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                icon: "bell.badge.fill",
                title: "Stay in the Loop",
                subtitle: "Get daily, weekly, or monthly budget reports as notifications."
            )
            NotificationSettingsView()
                .scrollContentBackground(.hidden)
        }
    }

    private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
        .padding(.top, 20)
        .padding(.bottom, 4)
    }
}

private struct OnboardingTemplatesStep: View {
    @Query(sort: \BudgetTemplate.createdAt) private var templates: [BudgetTemplate]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: AppSymbol.budgetTemplate)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
                Text("Budget Templates")
                    .font(.system(size: 28, weight: .bold))
                Text("A template is a day's budget, split into categories. We've made three to start. Tap one to adjust the amounts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            .padding(.top, 20)
            .padding(.bottom, 4)

            List {
                ForEach(templates) { template in
                    NavigationLink {
                        TemplateDetailView(template: template)
                    } label: {
                        HStack {
                            Label(template.name, systemImage: template.iconName)
                            Spacer()
                            Text(template.total.currencyString)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }
}

private struct OnboardingOverallBudgetsSection: View {
    @Query private var allSettings: [PlanSettings]

    var body: some View {
        if let settings = allSettings.first {
            @Bindable var settings = settings
            Section {
                LabeledContent("Weekly") {
                    TextField("0", value: $settings.weeklyOverallBudget, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Monthly") {
                    TextField("0", value: $settings.monthlyOverallBudget, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Overall Budgets (Optional)")
            } footer: {
                Text("For things that don't belong to a single day, like a weekly meal subscription or a monthly bulk buy.")
            }
        }
    }
}

private struct OnboardingCarryoverSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [PlanSettings]

    var body: some View {
        if let settings = allSettings.first {
            Section("When Budget Is Left Over or Exceeded") {
                ForEach(CarryoverBehavior.allCases) { behavior in
                    Button {
                        settings.carryover = behavior
                        try? modelContext.save()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(behavior.title)
                                    .font(.body.weight(.medium))
                                Text(behavior.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if settings.carryover == behavior {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .tint(.primary)
                }
            }
        }
    }
}
