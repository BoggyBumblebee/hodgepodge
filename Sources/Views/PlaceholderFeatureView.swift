import SwiftUI

struct PlaceholderFeatureView: View {
    let section: AppSection

    var body: some View {
        ContentUnavailableView(
            section.title,
            systemImage: section.systemImageName,
            description: Text("This section is scaffolded for a later phase and is intentionally left minimal for now.")
        )
        .accessibilityLabel(section.title)
    }
}
