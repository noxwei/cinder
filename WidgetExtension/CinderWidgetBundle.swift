import WidgetKit
import SwiftUI

// MARK: - Cinder Widget Bundle
// All 6 widgets registered here.

@main
struct CinderWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Heat tracking
        SmallWidget()       // Single hottest project (systemSmall)
        MediumWidget()      // Top 5 heat squares (systemMedium)
        LargeWidget()       // Full grid hottest-first (systemLarge + systemExtraLarge)

        // Motivation
        GraveyardWidget()   // Ash counter — shame-based (systemSmall + systemMedium)

        // Daily practice
        NudgeWidget()       // "What should I work on?" tarot card (systemSmall + systemMedium)
        StatsBarWidget()    // Ultra minimal numbers bar (systemSmall)
    }
}
