import SwiftData
import SwiftUI

@main
struct TopOnemacOSApp: App {
    var body: some Scene {
        WindowGroup {
            TopOneRootView()
                .frame(minWidth: 800, minHeight: 520)
                .modelContainer(PersistenceController.previewContainer)
        }
    }
}
