import CockpitCore
import SwiftUI

struct ContentPieceListView: View {
  let followingModel: FollowingModel
  let editionModel: EditionModel
  @State private var model = ContentPieceListModel()
  @State private var gmailAuthorizationProbe = GmailAuthorizationProbe()
  @State private var isPresentingGmailAuthorizationProbe = false

  var body: some View {
    NavigationStack {
      VStack {
        Picker("Destination", selection: $model.destination) {
          ForEach(ContentPieceListModel.Destination.allCases, id: \.self) { destination in
            Text(destination.rawValue).tag(destination)
          }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)

        List(model.rows) { row in
          ContentPieceRowView(row: row, model: model)
        }
        .overlay {
          if model.rows.isEmpty {
            ContentUnavailableView(
              model.destination == .all ? "No Content Pieces" : "Nothing in \(model.destination.rawValue)",
              systemImage: "newspaper",
              description: Text("Use Save for Later or Add to Library on an ingested piece.")
            )
          }
        }
      }
      .navigationTitle(model.destination == .all ? "Content Pieces" : model.destination.rawValue)
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          NavigationLink {
            SettingsView()
          } label: {
            Label("Settings", systemImage: "gearshape")
          }
          NavigationLink {
            EditionView(model: editionModel)
          } label: {
            Label("Edition", systemImage: "newspaper")
          }
          NavigationLink {
            FollowingView(model: followingModel)
          } label: {
            Label("Following", systemImage: "dot.radiowaves.left.and.right")
          }
          NavigationLink {
            PendingFindListView()
          } label: {
            Label("Finds", systemImage: "sparkle.magnifyingglass")
          }
          Button("Gmail authorization probe", systemImage: "envelope.badge") {
            isPresentingGmailAuthorizationProbe = true
          }
        }
      }
      .safeAreaInset(edge: .bottom) {
        if let error = model.errorMessage {
          HStack {
            Text(error)
            Button("Dismiss") { model.errorMessage = nil }
          }
          .padding()
          .background(.regularMaterial)
        }
      }
      .sheet(isPresented: $isPresentingGmailAuthorizationProbe) {
        GmailAuthorizationProbeView(probe: gmailAuthorizationProbe)
      }
    }
  }
}
