import SwiftData
import SwiftUI

struct OnboardingTemplatesStep: View {
    @Query(sort: \BudgetTemplate.createdAt) private var templates: [BudgetTemplate]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepHeader(
                icon: AppSymbol.budgetTemplate,
                title: "Onboarding.Templates.Title",
                subtitle: "Onboarding.Templates.Subtitle"
            )

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
            }
            .scrollContentBackground(.hidden)
        }
    }
}
