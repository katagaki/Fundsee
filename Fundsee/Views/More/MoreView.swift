import SwiftData
import SwiftUI

struct MoreView: View {
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true

    @Query private var templates: [BudgetTemplate]
    @Query private var entries: [SpendEntry]
    @Query private var allSettings: [PlanSettings]

    @State private var exportURL: URL?
    @State private var templatesExportURL: URL?

    var body: some View {
        NavigationStack {
            List {
                Section("More.Section.BudgetSetup") {
                    NavigationLink {
                        TemplatesEditorView()
                    } label: {
                        SettingsLabel(title: "More.BudgetTemplates", systemImage: AppSymbol.budgetTemplate, color: .green)
                    }
                    NavigationLink {
                        WeekPlanEditorView()
                    } label: {
                        SettingsLabel(title: "More.WeekPlan", systemImage: "calendar", color: .blue)
                    }
                    NavigationLink {
                        OverallBudgetsView()
                    } label: {
                        SettingsLabel(title: "More.OverallBudgets", systemImage: "basket.fill", color: .teal)
                    }
                }

                Section("More.Section.Behavior") {
                    NavigationLink {
                        CarryoverSettingsView()
                    } label: {
                        SettingsLabel(title: "More.Leftovers", systemImage: "arrow.uturn.forward", color: .orange)
                    }
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        SettingsLabel(title: "More.Notifications", systemImage: "bell.badge.fill", color: .red)
                    }
                }

                Section {
                    Toggle(isOn: $iCloudSyncEnabled) {
                        SettingsLabel(title: "More.ICloudSync", systemImage: "icloud.fill", color: .cyan)
                    }
                } footer: {
                    Text("More.ICloudSync.Footer")
                }

                Section("More.Section.Export") {
                    Button {
                        exportURL = try? CSVExporter.exportEntries(entries)
                    } label: {
                        SettingsLabel(title: "More.ExportSpending", systemImage: "square.and.arrow.up", color: .indigo)
                    }
                    .tint(.primary)
                    Button {
                        templatesExportURL = try? CSVExporter.exportTemplates(templates)
                    } label: {
                        SettingsLabel(title: "More.ExportTemplates", systemImage: "square.and.arrow.up.on.square", color: .purple)
                    }
                    .tint(.primary)
                }
            }
            .navigationTitle("More.Title")
            .toolbarTitleDisplayMode(.inlineLarge)
            .sheet(item: $exportURL) { url in
                ShareSheet(url: url)
            }
            .sheet(item: $templatesExportURL) { url in
                ShareSheet(url: url)
            }
        }
    }
}
