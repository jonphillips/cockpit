import CockpitCore
import SwiftUI

struct OfferReviewView: View {
  let role: ContentRole
  let didFinish: () -> Void
  @State private var model: OfferReviewModel
  @State private var readerRow: OfferReviewRequest.Row?
  @State private var originalWebViewStore = TodayOriginalWebViewStore()
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  init(role: ContentRole, todayModel: TodayModel, didFinish: @escaping () -> Void) {
    self.role = role
    self.didFinish = didFinish
    _model = State(initialValue: OfferReviewModel(role: role) {
      todayModel.rememberOfferBatch($0)
    })
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        if model.isClear {
          clearState
        } else {
          LazyVGrid(
            columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 280 : 300), spacing: 16)],
            alignment: .center,
            spacing: 16
          ) {
            ForEach(model.rows) { row in
              OfferReviewCard(row: row, role: role) {
                readerRow = row
              } keep: {
                guard let findID = row.pendingFind?.id else { return }
                Task {
                  if row.pendingFind?.state == .confirmed {
                    await model.unkeep(findID)
                  } else {
                    await model.keep(findID)
                  }
                }
              }
            }
          }
          .padding(.horizontal)
          .padding(.top, 12)
          .padding(.bottom, 18)
        }
      }
      .navigationTitle("\(role.displayName) offers")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Not now") { didFinish() }
        }
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        OfferReviewFinishBar(model: model, role: role, didFinish: didFinish)
      }
      .task { await model.reload() }
      .sheet(item: $readerRow, onDismiss: { Task { await model.reload() } }) { row in
        NavigationStack {
          ReaderView(
            contentPieceID: row.id,
            onSourceDisposed: {
              Task {
                readerRow = nil
                await model.reload()
              }
            },
            originalWebViewStore: originalWebViewStore
          )
          .toolbar {
            ToolbarItem(placement: .topBarLeading) {
              Button("Done", systemImage: "checkmark") { readerRow = nil }
            }
          }
        }
        .presentationSizing(.page)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
      }
    }
  }

  private var clearState: some View {
    VStack(spacing: 10) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 42))
        .foregroundStyle(.green)
      Text("\(role.displayName) is clear").font(.title2.weight(.semibold))
      Text("You reviewed every offer in this group.")
        .foregroundStyle(.secondary)
      Button("Done") { didFinish() }.padding(.top, 6)
    }
    .frame(maxWidth: .infinity, minHeight: 300)
    .padding()
  }
}
