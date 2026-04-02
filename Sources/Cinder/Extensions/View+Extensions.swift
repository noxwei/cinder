import SwiftUI

// Label style that tints the icon with a custom color
struct TintedIconLabelStyle: LabelStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
                .foregroundStyle(color)
            configuration.title
        }
    }
}
