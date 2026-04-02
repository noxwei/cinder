import SwiftData
import Foundation

enum SwipeDirection: String, Codable {
    case reignite = "reignite"
    case snooze   = "snooze"
    case archive  = "archive"
}

@Model
final class SwipeRecord {
    var projectPath: String
    var projectName: String
    var directionRaw: String
    var timestamp: Date
    var snoozeUntil: Date?

    init(
        projectPath: String,
        projectName: String,
        direction: SwipeDirection,
        timestamp: Date = .now,
        snoozeUntil: Date? = nil
    ) {
        self.projectPath = projectPath
        self.projectName = projectName
        self.directionRaw = direction.rawValue
        self.timestamp = timestamp
        self.snoozeUntil = snoozeUntil
    }

    var direction: SwipeDirection {
        SwipeDirection(rawValue: directionRaw) ?? .snooze
    }
}
