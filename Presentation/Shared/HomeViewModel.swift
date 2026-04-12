import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var headline: String

    init(headline: String = "TopOne") {
        self.headline = headline
    }
}
