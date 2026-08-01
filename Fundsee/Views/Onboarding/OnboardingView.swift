import SwiftData
import SwiftUI

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
            .toolbarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { bottomBar }
            .toolbar {
                if step > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.standard) { step -= 1 }
                        } label: {
                            Image(systemName: "chevron.backward")
                        }
                        .accessibilityLabel("Common.Back")
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
                Text("Onboarding.Privacy")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Button {
                if step == stepCount - 1 {
                    hasCompletedOnboarding = true
                } else {
                    withAnimation(.standard) { step += 1 }
                }
            } label: {
                Text(step == stepCount - 1 ? LocalizedStringKey("Onboarding.Start") : LocalizedStringKey("Onboarding.Continue"))
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
                    Text("Onboarding.Welcome.Title")
                        .font(.system(size: 34, weight: .bold))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
                .padding(.bottom, 40)

                VStack(alignment: .leading, spacing: 28) {
                    featureRow(
                        icon: AppSymbol.budgetTemplate,
                        title: "Onboarding.Feature.Templates.Title",
                        subtitle: "Onboarding.Feature.Templates.Subtitle"
                    )
                    featureRow(
                        icon: "calendar.badge.clock",
                        title: "Onboarding.Feature.WeekPlan.Title",
                        subtitle: "Onboarding.Feature.WeekPlan.Subtitle"
                    )
                    featureRow(
                        icon: "chart.bar.xaxis",
                        title: "Onboarding.Feature.Insights.Title",
                        subtitle: "Onboarding.Feature.Insights.Subtitle"
                    )
                }
                .padding(.horizontal, 36)
            }
        }
    }

    private func featureRow(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
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
                title: "Onboarding.WeekPlan.Title",
                subtitle: "Onboarding.WeekPlan.Subtitle"
            )
            WeekPlanEditorView(isEmbedded: true)
                .scrollContentBackground(.hidden)
        }
    }

    private var budgetsAndBehaviorStep: some View {
        VStack(spacing: 0) {
            stepHeader(
                icon: "basket.fill",
                title: "Onboarding.Extras.Title",
                subtitle: "Onboarding.Extras.Subtitle"
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
                title: "Onboarding.Notifications.Title",
                subtitle: "Onboarding.Notifications.Subtitle"
            )
            NotificationSettingsView(isEmbedded: true)
                .scrollContentBackground(.hidden)
        }
    }

    private func stepHeader(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        OnboardingStepHeader(icon: icon, title: title, subtitle: subtitle)
    }
}
