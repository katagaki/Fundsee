import SwiftUI

struct BudgetSummaryHeader<Footer: View>: View {
    var used: Decimal
    var budget: Decimal
    var caption: String
    var carryover: Decimal = 0
    var spendPalette: [SpendSlice] = []
    var extraArcs: [ExtraArc] = []
    @ViewBuilder var footer: Footer

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            BudgetRingView(
                used: used,
                budget: budget,
                centerCaption: caption,
                carryover: carryover,
                spendPalette: spendPalette,
                extraArcs: extraArcs,
                showsLabel: false
            )
            .frame(width: 132, height: 132)

            VStack(alignment: .leading, spacing: 8) {
                BudgetRingLabel(used: used, budget: budget, caption: caption)
                footer
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }
}

extension BudgetSummaryHeader where Footer == EmptyView {
    init(
        used: Decimal,
        budget: Decimal,
        caption: String,
        carryover: Decimal = 0,
        spendPalette: [SpendSlice] = [],
        extraArcs: [ExtraArc] = []
    ) {
        self.init(
            used: used,
            budget: budget,
            caption: caption,
            carryover: carryover,
            spendPalette: spendPalette,
            extraArcs: extraArcs,
            footer: { EmptyView() }
        )
    }
}
