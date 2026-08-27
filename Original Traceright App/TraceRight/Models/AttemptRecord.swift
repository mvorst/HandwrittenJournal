import Foundation
import SwiftData

@Model
final class AttemptRecord {
    var date: Date
    var text: String
    var level: Int
    var accuracy: Double
    var coverage: Double
    var starsEarned: Int
    var pointsEarned: Int

    init(date: Date = .now, text: String, level: Int, accuracy: Double, coverage: Double = 0, starsEarned: Int, pointsEarned: Int) {
        self.date = date
        self.text = text
        self.level = level
        self.accuracy = accuracy
        self.coverage = coverage
        self.starsEarned = starsEarned
        self.pointsEarned = pointsEarned
    }
}
