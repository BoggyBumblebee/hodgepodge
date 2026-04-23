import SwiftUI

struct SectionFilterMenu<Filter: CaseIterable & Identifiable & Hashable>: View
where Filter.AllCases: RandomAccessCollection {
    let activeCount: Int
    let activeFilters: Set<Filter>
    let title: (Filter) -> String
    let toggle: (Filter) -> Void
    let clear: () -> Void

    var body: some View {
        Menu {
            ForEach(Array(Filter.allCases)) { filter in
                Toggle(isOn: binding(for: filter)) {
                    Text(title(filter))
                }
            }

            Divider()

            Button("Clear Filters", action: clear)
                .disabled(activeFilters.isEmpty)
        } label: {
            Label(
                activeCount == 0 ? "Filters" : "Filters (\(activeCount))",
                systemImage: "line.3.horizontal.decrease.circle"
            )
        }
    }

    private func binding(for filter: Filter) -> Binding<Bool> {
        Binding(
            get: { activeFilters.contains(filter) },
            set: { isActive in
                if isActive != activeFilters.contains(filter) {
                    toggle(filter)
                }
            }
        )
    }
}

struct CatalogScopePicker: View {
    @Binding var scope: CatalogScope

    var body: some View {
        Picker("Package Scope", selection: $scope) {
            ForEach(CatalogScope.allCases) { scope in
                Text(scope.title).tag(scope)
            }
        }
        .pickerStyle(.segmented)
    }
}

struct SectionCountLabel: View {
    let count: Int
    let noun: String

    var body: some View {
        Text("\(count) \(noun)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
