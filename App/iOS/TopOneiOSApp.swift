import SwiftData
import SwiftUI

@main
struct TopOneiOSApp: App {
    var body: some Scene {
        WindowGroup {
            TopOneRootView()
                .modelContainer(PersistenceController.previewContainer)
        }
    }
}
