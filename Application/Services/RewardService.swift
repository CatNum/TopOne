import Foundation
#if canImport(AppKit)
import AppKit
typealias RewardPlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
typealias RewardPlatformImage = UIImage
#endif
import ImageIO
import SwiftData
import UniformTypeIdentifiers

enum RewardPointSource: Equatable {
    case dailyTask(rank: TaskRank, title: String)
    case goal(rank: TaskRank, title: String)
}

enum RewardServiceError: Error, Equatable {
    case invalidRewardName
    case rewardImageRequired
    case invalidLimitedRewardCount
    case insufficientPoints(required: Int, actual: Int)
    case rewardNotFound(rank: TaskRank)
    case rewardUnavailable
    case invalidUseAmount
    case insufficientInventory
}

struct RewardService {
    static let minRewardNameLength = 1
    static let maxRewardNameLength = 32
    static let maxStoredImagePixelSize: CGFloat = 256

    @MainActor
    private static let decodedImageCache = NSCache<NSData, RewardPlatformImage>()

    private let dailyTaskPoints: [TaskRank: Int] = [
        .s: 12,
        .a: 8,
        .b: 5,
        .c: 3,
    ]

    private let goalPoints: [TaskRank: Int] = [
        .s: 20,
        .a: 10,
        .b: 6,
        .c: 4,
    ]

    private let drawCosts: [TaskRank: Int] = [
        .s: 12,
        .a: 5,
        .b: 3,
        .c: 2,
    ]

    @discardableResult
    func createRewardDefinition(name: String, icon: String = "", iconImageData: Data, rank: TaskRank, detail: String = "", availabilityMode: RewardAvailabilityMode = .unlimited, remainingCount: Int = 0, in modelContext: ModelContext) throws -> RewardDefinition {
        guard Self.isValidRewardName(name) else {
            throw RewardServiceError.invalidRewardName
        }
        guard Self.hasRewardImage(iconImageData) else {
            throw RewardServiceError.rewardImageRequired
        }
        guard availabilityMode == .unlimited || remainingCount > 0 else {
            throw RewardServiceError.invalidLimitedRewardCount
        }

        let optimizedImageData = Self.optimizedImageData(from: iconImageData)
        let reward = RewardDefinition(
            name: name,
            icon: icon,
            iconImageData: optimizedImageData,
            rank: rank,
            detail: detail,
            availabilityMode: availabilityMode,
            remainingCount: availabilityMode == .limited ? remainingCount : 0
        )
        modelContext.insert(reward)
        try modelContext.save()
        return reward
    }

    func updateRewardDefinition(_ reward: RewardDefinition, name: String, icon: String = "", iconImageData: Data, rank: TaskRank, detail: String = "", availabilityMode: RewardAvailabilityMode = .unlimited, remainingCount: Int = 0, in modelContext: ModelContext) throws {
        guard Self.isValidRewardName(name) else {
            throw RewardServiceError.invalidRewardName
        }
        guard Self.hasRewardImage(iconImageData) else {
            throw RewardServiceError.rewardImageRequired
        }
        guard availabilityMode == .unlimited || remainingCount > 0 else {
            throw RewardServiceError.invalidLimitedRewardCount
        }

        reward.name = RewardDefinition.normalizedName(from: name)
        reward.icon = RewardDefinition.normalizedIcon(from: icon)
        reward.iconImageData = Self.optimizedImageData(from: iconImageData)
        reward.rank = rank
        reward.detail = RewardDefinition.normalizedDetail(from: detail)
        reward.availabilityMode = availabilityMode
        reward.remainingCount = availabilityMode == .limited ? max(0, remainingCount) : 0
        try modelContext.save()
    }

    func deleteRewardDefinition(_ reward: RewardDefinition, in modelContext: ModelContext) throws {
        modelContext.delete(reward)
        try modelContext.save()
    }

    @discardableResult
    func ensureRewardAccount(in modelContext: ModelContext) throws -> RewardAccount {
        if let existingAccount = fetchRewardAccount(in: modelContext) {
            return existingAccount
        }

        let account = RewardAccount()
        modelContext.insert(account)
        try modelContext.save()
        return account
    }

    func fetchRewardAccount(in modelContext: ModelContext) -> RewardAccount? {
        let descriptor = FetchDescriptor<RewardAccount>()
        return try? modelContext.fetch(descriptor).first
    }

    @discardableResult
    func awardPoints(for source: RewardPointSource, in modelContext: ModelContext) throws -> RewardAccount {
        let account = try ensureRewardAccount(in: modelContext)
        let delta: Int
        let reason: RewardPointChangeReason
        let rank: TaskRank
        let title: String

        switch source {
        case let .dailyTask(taskRank, taskTitle):
            delta = dailyTaskPoints[taskRank] ?? 0
            reason = .completeDailyTask
            rank = taskRank
            title = taskTitle
        case let .goal(goalRank, goalTitle):
            delta = goalPoints[goalRank] ?? 0
            reason = .completeGoal
            rank = goalRank
            title = goalTitle
        }

        account.points += delta
        recordPointTransaction(
            delta: delta,
            balanceAfterChange: account.points,
            kind: .earn,
            reason: reason,
            rank: rank,
            referenceTitle: title,
            in: modelContext
        )
        try modelContext.save()
        return account
    }

    @discardableResult
    func drawReward(for rank: TaskRank, in modelContext: ModelContext) throws -> RewardDefinition {
        let account = try ensureRewardAccount(in: modelContext)
        let cost = drawCost(for: rank)
        guard account.points >= cost else {
            throw RewardServiceError.insufficientPoints(required: cost, actual: account.points)
        }

        let rewards = try availableRewards(for: rank, in: modelContext)
        guard let reward = rewards.randomElement() else {
            throw RewardServiceError.rewardNotFound(rank: rank)
        }

        account.points -= cost
        recordPointTransaction(
            delta: -cost,
            balanceAfterChange: account.points,
            kind: .spend,
            reason: .drawReward,
            rank: rank,
            referenceTitle: reward.name,
            in: modelContext
        )
        if reward.availabilityMode == .limited {
            reward.remainingCount -= 1
        }

        let inventoryItem = reward.inventoryItems.first ?? RewardInventoryItem(currentCount: 0, rewardDefinition: reward)
        if inventoryItem.modelContext == nil {
            modelContext.insert(inventoryItem)
        }
        inventoryItem.currentCount += 1

        try modelContext.save()
        return reward
    }

    func useReward(_ inventoryItem: RewardInventoryItem, amount: Int, in modelContext: ModelContext) throws {
        guard amount > 0 else {
            throw RewardServiceError.invalidUseAmount
        }
        guard inventoryItem.currentCount >= amount else {
            throw RewardServiceError.insufficientInventory
        }

        inventoryItem.currentCount -= amount
        try modelContext.save()
    }

    func drawCost(for rank: TaskRank) -> Int {
        drawCosts[rank] ?? 0
    }

    func availableRewards(for rank: TaskRank, in modelContext: ModelContext) throws -> [RewardDefinition] {
        let descriptor = FetchDescriptor<RewardDefinition>(sortBy: [SortDescriptor(\.name)])
        return try modelContext.fetch(descriptor).filter {
            $0.rank == rank && ($0.availabilityMode == .unlimited || $0.remainingCount > 0)
        }
    }

    func fetchPointTransactions(in modelContext: ModelContext) throws -> [RewardPointTransaction] {
        let descriptor = FetchDescriptor<RewardPointTransaction>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try modelContext.fetch(descriptor)
    }

    private func recordPointTransaction(
        delta: Int,
        balanceAfterChange: Int,
        kind: RewardPointChangeKind,
        reason: RewardPointChangeReason,
        rank: TaskRank,
        referenceTitle: String,
        in modelContext: ModelContext
    ) {
        let transaction = RewardPointTransaction(
            pointsDelta: delta,
            balanceAfterChange: balanceAfterChange,
            kind: kind,
            reason: reason,
            rank: rank,
            referenceTitle: referenceTitle
        )
        modelContext.insert(transaction)
    }

    static func isValidRewardName(_ name: String) -> Bool {
        let normalized = RewardDefinition.normalizedName(from: name)
        return normalized.count >= minRewardNameLength && normalized.count <= maxRewardNameLength
    }

    static func hasRewardImage(_ data: Data) -> Bool {
        !data.isEmpty
    }

    static func optimizedImageData(from data: Data) -> Data {
        guard !data.isEmpty else { return data }
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return data
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxStoredImagePixelSize),
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return data
        }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return data
        }
        CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.78] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return data
        }
        return mutableData as Data
    }

    @MainActor
    static func decodedImage(from data: Data) -> RewardPlatformImage? {
        guard !data.isEmpty else { return nil }
        let cacheKey = data as NSData
        if let cached = decodedImageCache.object(forKey: cacheKey) {
            return cached
        }
        guard let image = RewardPlatformImage(data: data) else {
            return nil
        }
        decodedImageCache.setObject(image, forKey: cacheKey)
        return image
    }
}
