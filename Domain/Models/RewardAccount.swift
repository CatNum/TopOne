import Foundation
import SwiftData

@Model
final class RewardAccount {
    private static let emptyEncodedDictionary = Data("{}".utf8)

    var points: Int
    var lastPointResetAt: Date?

    var dailyTaskPointsAwardedRawValue: Int?
    var didAwardGoalPointsTodayRawValue: Bool?
    var drawCountsByTierRawValue: Data?
    var exchangeCreditsByTierRawValue: Data?

    var dailyTaskPointsAwarded: Int {
        get {
            max(0, dailyTaskPointsAwardedRawValue ?? 0)
        }
        set {
            dailyTaskPointsAwardedRawValue = max(0, newValue)
        }
    }

    var didAwardGoalPointsToday: Bool {
        get {
            didAwardGoalPointsTodayRawValue ?? false
        }
        set {
            didAwardGoalPointsTodayRawValue = newValue
        }
    }

    var drawCountsByTier: [String: Int] {
        get {
            decodePersistedDictionary(from: drawCountsByTierRawValue)
        }
        set {
            drawCountsByTierRawValue = encodePersistedDictionary(newValue)
        }
    }

    var exchangeCreditsByTier: [String: Int] {
        get {
            decodePersistedDictionary(from: exchangeCreditsByTierRawValue)
        }
        set {
            exchangeCreditsByTierRawValue = encodePersistedDictionary(newValue)
        }
    }

    init(
        points: Int = 0,
        lastPointResetAt: Date? = nil,
        dailyTaskPointsAwarded: Int = 0,
        didAwardGoalPointsToday: Bool = false,
        drawCountsByTier: [String: Int] = [:],
        exchangeCreditsByTier: [String: Int] = [:]
    ) {
        self.points = max(0, points)
        self.lastPointResetAt = lastPointResetAt
        dailyTaskPointsAwardedRawValue = max(0, dailyTaskPointsAwarded)
        didAwardGoalPointsTodayRawValue = didAwardGoalPointsToday
        drawCountsByTierRawValue = Self.encodePersistedDictionary(drawCountsByTier)
        exchangeCreditsByTierRawValue = Self.encodePersistedDictionary(exchangeCreditsByTier)
    }

    private func decodePersistedDictionary(from data: Data?) -> [String: Int] {
        Self.decodePersistedDictionary(from: data)
    }

    private func encodePersistedDictionary(_ dictionary: [String: Int]) -> Data {
        Self.encodePersistedDictionary(dictionary)
    }

    private static func decodePersistedDictionary(from data: Data?) -> [String: Int] {
        guard let data,
              let dictionary = try? JSONDecoder().decode([String: Int].self, from: data)
        else {
            return [:]
        }
        return dictionary
    }

    private static func encodePersistedDictionary(_ dictionary: [String: Int]) -> Data {
        guard let encoded = try? JSONEncoder().encode(dictionary) else {
            return emptyEncodedDictionary
        }
        return encoded
    }
}
