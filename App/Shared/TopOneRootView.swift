import SwiftUI

struct TopOneRootView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("TopOne")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("工程基线已建立，后续功能将在此基础上继续推进。")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
            .navigationTitle("Home")
        }
    }
}
