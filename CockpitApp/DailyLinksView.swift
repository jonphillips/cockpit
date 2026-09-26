import CockpitCore
import SwiftUI

struct DailyLinksColumn: View {
  @Bindable var model: DailyLinkModel
  @Environment(\.openURL) private var openURL

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      VStack(spacing: 14) {
        ForEach(model.links) { link in
          let visited = link.isVisited(on: context.date)
          Button {
            open(link)
          } label: {
            VStack(spacing: 2) {
              Image(systemName: link.symbolName)
                .font(.system(size: 22))
                .frame(width: 36, height: 32)
              if visited {
                Image(systemName: "checkmark")
                  .font(.system(size: 9, weight: .bold))
              } else {
                Color.clear.frame(height: 9)
              }
            }
            .foregroundStyle(visited ? .secondary : .primary)
            .frame(width: 56)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .opacity(visited ? 0.55 : 1)
          .accessibilityLabel(link.title)
          .help(link.title)
          .contextMenu {
            Button("Open \(link.title)", systemImage: link.symbolName) { open(link) }
          }
        }
        Spacer(minLength: 0)
      }
      .padding(.top, 62)
      .frame(width: 56)
    }
  }

  private func open(_ link: DailyLink) {
    guard let url = URL(string: link.url) else { return }
    openURL(url) { accepted in
      guard accepted else { return }
      Task { await model.recordVisit(link.id) }
    }
  }
}

struct DailyLinksMenu: View {
  @Bindable var model: DailyLinkModel
  @Environment(\.openURL) private var openURL

  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      Menu {
        ForEach(model.links) { link in
          Button {
            guard let url = URL(string: link.url) else { return }
            openURL(url) { accepted in
              guard accepted else { return }
              Task { await model.recordVisit(link.id) }
            }
          } label: {
            Label(link.title, systemImage: link.isVisited(on: context.date) ? "checkmark" : link.symbolName)
          }
        }
      } label: {
        Image(systemName: "link")
      }
      .accessibilityLabel("Daily links")
    }
  }
}

struct DailyLinksView: View {
  @Bindable var model: DailyLinkModel
  @State private var editor: Editor?

  var body: some View {
    List {
      Section {
        ForEach(model.links) { link in
          Button {
            editor = Editor(draft: DailyLinkDraft(
              id: link.id, title: link.title, url: link.url, symbolName: link.symbolName))
          } label: {
            Label(link.title, systemImage: link.symbolName)
              .foregroundStyle(.primary)
          }
          .swipeActions {
            Button("Delete", systemImage: "trash", role: .destructive) {
              Task { await model.delete(link.id) }
            }
          }
        }
        .onMove { source, destination in
          guard let first = source.first else { return }
          Task { await model.move(from: first, to: destination) }
        }
      } footer: {
        Text("In News, open a channel, tap Share → Copy Link, and paste it here.")
      }

      if let errorMessage = model.errorMessage {
        Section {
          Text(errorMessage).foregroundStyle(.red)
        }
      }
    }
    .navigationTitle("Daily links")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) { EditButton() }
      ToolbarItem(placement: .topBarTrailing) {
        Button("Add", systemImage: "plus") { editor = Editor(draft: DailyLinkDraft()) }
      }
    }
    .task { try? await model.$content.load() }
    .sheet(item: $editor) { item in
      DailyLinkEditorSheet(model: model, draft: item.draft)
    }
  }
}

private struct Editor: Identifiable {
  let id = UUID()
  var draft: DailyLinkDraft
}

private struct DailyLinkEditorSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var model: DailyLinkModel
  @State var draft: DailyLinkDraft
  @State private var validationMessage: String?

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

        Section("Icon") {
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
    .presentationDetents([.medium, .large])
  }
}
