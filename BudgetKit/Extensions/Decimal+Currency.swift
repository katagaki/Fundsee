import Foundation

extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }

    var currencyString: String {
        self.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    var compactCurrencyString: String {
        self.formatted(
            .currency(code: Locale.current.currency?.identifier ?? "USD")
            .precision(.fractionLength(0))
        )
    }
}
