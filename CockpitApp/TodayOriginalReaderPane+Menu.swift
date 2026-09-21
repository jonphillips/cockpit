import CockpitCore
import SwiftUI

extension TodayOriginalReaderPane {
  var readerMenu: some View {
    Menu {
      SenderTreatmentSubmenu(currentTreatment: model.treatment) { treatment in
        Task {
          let reclassified = await todayModel.setSenderOverride(treatment, for: model.sender)
          if let piece = reclassified.first(where: { $0.id == presentation.id }) {
            model.treatment = piece.emailTreatment
          }
        }
      }
      if let row = currentRow {
        Divider()
        if seriesTrashStateLoaded, row.treatment == .newsletter {
          if isSeriesTrashDeclared {
            Button("Stop auto-trashing \(model.publisher)", systemImage: "hand.raised") {
              Task {
                await todayModel.undeclareSeriesTrash(for: row)
                isSeriesTrashDeclared = await todayModel.seriesTrashState(for: row)
              }
            }
          } else {
            Button("Always trash \(model.publisher) after reading", systemImage: "trash") {
              Task {
                await todayModel.declareSeriesTrash(for: row)
                isSeriesTrashDeclared = await todayModel.seriesTrashState(for: row)
              }
            }
            Button("Trash", systemImage: "trash", role: .destructive) {
              Task { await disposeAndAdvance { await todayModel.trash($0) } }
            }
          }
        } else if seriesTrashStateLoaded {
          Button("Trash", systemImage: "trash", role: .destructive) {
            Task { await disposeAndAdvance { await todayModel.trash($0) } }
          }
        }
        Button("Undo disposition", systemImage: "arrow.uturn.backward") {
          Task { await todayModel.undoDisposition(row) }
        }
      }
    } label: {
      Image(systemName: "ellipsis.circle")
    }
    .disabled(model.sender.isEmpty && currentRow == nil)
    .accessibilityLabel("More reader tools")
  }
}
