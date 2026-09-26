import CockpitCore
import PhotosUI
import SwiftUI

struct DailyLinkEditorSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var model: DailyLinkModel
  @State var draft: DailyLinkDraft
  @State private var validationMessage: String?
  @State private var photoSelection: PhotosPickerItem?
  @State private var thumbnailMessage: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("Link") {
          TextField("Title", text: $draft.title)
            .textInputAutocapitalization(.words)
          TextField("https://…", text: $draft.url)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
          if let validationMessage {
            Text(validationMessage).font(.footnote).foregroundStyle(.red)
          }
        }

        Section {
          HStack(spacing: 16) {
            DailyLinkGlyph(symbolName: draft.symbolName, thumbnail: draft.thumbnail, size: 56)
              .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) {
              PhotosPicker(
                draft.thumbnail == nil ? "Choose from Photos" : "Replace Photo",
                selection: $photoSelection, matching: .images)
              if draft.thumbnail != nil {
                Button("Remove Thumbnail", role: .destructive) { draft.thumbnail = nil }
              }
            }
            .buttonStyle(.borderless)
          }
          .padding(.vertical, 4)
          if let thumbnailMessage {
            Text(thumbnailMessage).font(.footnote).foregroundStyle(.red)
          }
        } header: {
          Text("Thumbnail")
        }

        Section {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 12) {
            ForEach(DailyLinkIcon.symbols, id: \.self) { symbol in
              Button {
                draft.symbolName = symbol
              } label: {
                Image(systemName: symbol)
                  .font(.title2)
                  .frame(width: 44, height: 44)
                  .foregroundStyle(draft.symbolName == symbol ? Color.accentColor : .primary)
                  .background {
                    if draft.symbolName == symbol {
                      RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.14))
                    }
                  }
              }
              .buttonStyle(.plain)
              .accessibilityLabel(symbol)
              .accessibilityAddTraits(draft.symbolName == symbol ? .isSelected : [])
            }
          }
          .padding(.vertical, 4)
        } header: {
          Text("Icon")
        } footer: {
          Text("Shown when the link has no thumbnail.")
        }
      }
      .navigationTitle(draft.id == nil ? "Add Daily link" : "Edit Daily link")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task {
              if await model.save(draft) {
                dismiss()
              } else {
                validationMessage = model.errorMessage
              }
            }
          }
        }
      }
    }
    .task(id: photoSelection) { await loadThumbnail() }
    .presentationDetents([.medium, .large])
  }
}

extension DailyLinkEditorSheet {
  private func loadThumbnail() async {
    guard let photoSelection else { return }
    do {
      guard let data = try await photoSelection.loadTransferable(type: Data.self) else {
        throw DailyLinkThumbnail.Failure.unreadableImage
      }
      let thumbnail = try await Task.detached { try DailyLinkThumbnail.make(from: data) }.value
      draft.thumbnail = thumbnail
      thumbnailMessage = nil
    } catch is CancellationError {
      return
    } catch {
      thumbnailMessage = error.localizedDescription
    }
    self.photoSelection = nil
  }
}
