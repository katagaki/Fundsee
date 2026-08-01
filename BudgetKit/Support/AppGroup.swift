import Foundation
import SwiftData

enum AppGroup {
    static let identifier = "group.com.tsubuzaki.Fundsee"

    static let schema = Schema([
        BudgetTemplate.self,
        TemplateCategory.self,
        DayOverride.self,
        SpendEntry.self,
        PlanSettings.self,
    ])

    /// Read-only container for extensions (widgets) — local store, no CloudKit.
    static func readOnlyContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(identifier),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
