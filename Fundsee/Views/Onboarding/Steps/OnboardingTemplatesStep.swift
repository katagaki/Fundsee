import SwiftData
import SwiftUI

struct OnboardingTemplatesStep: View {
    @Query(sort: \BudgetTemplate.createdAt) private var templates: [BudgetTemplate]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: AppSymbol.budgetTemplate)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
                Text("Onboarding.Templates.Title")
                    .font(.system(size: 28, weight: .bold))
                Text("Onboarding.Templates.Subtitle")
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
