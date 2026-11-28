import CockpitCore
import SwiftUI

struct MorningPrepSettingsView: View {
  let model: MorningPrep

  var body: some View {
    List {
      Section {
        Text("Set up a personal automation in Shortcuts: choose Time of Day, set 6:50 AM, add Prepare Cockpit, and turn off Ask Before Running.")
          .font(.callout)
        if let failure = model.scheduleFailure {
          Text("Background refresh couldn't be scheduled: \(failure)")
            .foregroundStyle(.secondary)
        }
      } header: {
        Text("Set up the automation")
      }

      Section("Last 14 days") {
        if model.records.isEmpty {
          ContentUnavailableView("No runs yet", systemImage: "sunrise")
        } else {
          ForEach(model.records) { run in
            DisclosureGroup {
              if run.outcome == .alreadyReady {
                LabeledContent("Result", value: "Already ready")
              } else {
                LabeledContent("Mail", value: mailDescription(run.mail))
                LabeledContent("Feeds", value: feedsDescription(run.feeds))
                LabeledContent("Offer summaries", value: summariesDescription(run.summaries))
              }
            } label: {
              VStack(alignment: .leading, spacing: 3) {
                HStack {
                  Text(status(for: run)).fontWeight(.semibold)
                  Spacer()
                  Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
                }
                Text("\(triggerName(run.trigger)) · \(run.endedAt?.formatted(date: .omitted, time: .shortened) ?? "Didn't finish")")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
      }
    }
    .navigationTitle("Morning prep")
  }

  private func status(for run: MorningPrepRun) -> String {
    if run.outcome == .alreadyReady { return "Already ready" }
    guard let day = model.days.first(where: { value in
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = TimeZone(identifier: value.timeZoneID) ?? .current
      return calendar.isDate(run.startedAt, inSameDayAs: value.firstOpenAt)
    }) else { return "Not ready" }
    return model.readyRun(on: day)?.id == run.id ? "Ready" : "Not ready"
  }

  private func triggerName(_ trigger: MorningPrepTrigger) -> String {
    switch trigger {
    case .manualPrepare: "Prepare button"
    default: trigger.rawValue.capitalized
    }
  }

  private func mailDescription(_ result: MorningPrepMailResult?) -> String {
    switch result {
    case let .synced(count): "Synced · \(count) messages"
    case .skippedFresh: "Skipped · already fresh"
    case .notAuthorized: "Not updated · sign in to Gmail"
    case let .failed(message): "Failed · \(message)"
    case .outOfTime: "Out of time"
    case nil: "Didn't finish"
    }
  }

  private func feedsDescription(_ result: MorningPrepFeedsResult?) -> String {
    switch result {
    case let .completed(succeeded, attempted): "\(succeeded) of \(attempted) loaded"
    case .skippedFresh: "Skipped · already fresh"
    case .outOfTime: "Out of time"
    case nil: "Didn't finish"
    }
  }

  private func summariesDescription(_ result: MorningPrepSummariesResult?) -> String {
    switch result {
    case let .completed(done, waiting): "\(done) done · \(waiting) waiting"
    case .skipped: "Skipped"
    case .outOfTime: "Out of time"
    case nil: "Didn't finish"
    }
  }
}
