import SwiftUI

// MARK: - Overview Tab (Home Page)

struct OverviewTab: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        OverviewTabBackendSection()
        OverviewTabConnectionSection()
        OverviewTabAboutSection()
      }
      .padding()
    }
  }
}
