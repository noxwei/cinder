import WidgetKit
import SwiftUI

// MARK: - Cinder Widget Bundle
// All 6 widgets registered here.
// The graveyard one is the one we'd actually use. 墓地即动力。🪦

@main
struct CinderWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Heat tracking
        SmallWidget()       // Single hottest project (2×2)
        MediumWidget()      // Top 5 heat squares (4×2)
        LargeWidget()       // Full grid sorted hottest-first (4×4)

        // Shame-based motivation
        GraveyardWidget()   // Ash counter — the fan favourite

        // Daily practice
        NudgeWidget()       // "What should I work on?" tarot card
        StatsBarWidget()    // Ultra minimal numbers bar + accessory rect
    }
}
