import SwiftData

enum PersistenceController {
    @MainActor
    static let previewContainer: ModelContainer = {
        let schema = Schema([
            Goal.self,
            DailyTask.self,
            RewardDefinition.self,
            RewardAccount.self,
            RewardInventoryItem.self,
            RewardPointTransaction.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create preview model container: \(error)")
        }
    }()
}
