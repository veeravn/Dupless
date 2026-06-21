import SwiftUI
import SwiftData

/// The work a progress screen performs: a fresh scan or a resumed one.
enum ScanJob {
    case fresh(scope: ScanScope, options: ScanOptions, sensitivity: SimilaritySensitivity)
    case droneBurst(scope: ScanScope, options: ScanOptions, droneOptions: DroneBurstOptions)
    case resume(ScanCheckpointRecord)

    var isDroneBurst: Bool { if case .droneBurst = self { return true }; return false }

    /// The content/subject filter for an AI-scoped scan, if any.
    var contentQuery: String? {
        if case let .fresh(_, options, _) = self { return options.contentQuery }
        return nil
    }
}

/// Runs the scan and shows the five stages from the spec. On completion, offers
/// a button to review the duplicate groups.
struct ScanProgressView: View {
    let job: ScanJob

    @Environment(ScanEngine.self) private var engine
    @Environment(\.modelContext) private var modelContext

    @State private var finished = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ProgressView(value: engine.progress) {
                Text(engine.stage?.rawValue ?? (finished ? "Done" : "Starting…"))
                    .font(.headline)
            }
            .progressViewStyle(.linear)
            .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(ScanStage.allCases, id: \.self) { stage in
                    StageRow(stage: stage, current: engine.stage, finished: finished)
                }
            }

            Spacer()

            if engine.isThrottling {
                Label("Slowing down to protect your device's temperature and battery.",
                      systemImage: "thermometer.medium")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            if finished, let query = job.contentQuery {
                contentMatchNote(query: query)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            if finished, engine.skippedCount > 0 {
                Label("^[\(engine.skippedCount) photo](inflect: true) couldn't be analyzed — they may be in iCloud and not downloaded.",
                      systemImage: "icloud.slash")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            if finished {
                NavigationLink {
                    if job.isDroneBurst {
                        SessionClusterListView()
                    } else {
                        DuplicateGroupListView()
                    }
                } label: {
                    completionText
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 40)
            }
        }
        .padding()
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .navigationTitle("Scanning")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(engine.isScanning)
        .interactiveDismissDisabled(engine.isScanning)
        .task {
            guard !finished else { return }
            switch job {
            case let .fresh(scope, options, sensitivity):
                await engine.scan(scope: scope, options: options, sensitivity: sensitivity, modelContext: modelContext)
            case let .droneBurst(scope, options, droneOptions):
                await engine.scanDroneBurst(scope: scope, options: options, droneOptions: droneOptions, modelContext: modelContext)
            case let .resume(checkpoint):
                await engine.resume(checkpoint: checkpoint, modelContext: modelContext)
            }
            finished = true
        }
    }

    // Inflection markup only works when a string *literal* is passed to Text, so
    // these are built inline rather than via a computed String.
    @ViewBuilder
    private var completionText: some View {
        if engine.lastResultCount == 0 {
            Text(job.isDroneBurst ? "No Sessions Found" : "No Duplicates Found")
        } else if job.isDroneBurst {
            Text("Review ^[\(engine.lastResultCount) Session](inflect: true)")
        } else {
            Text("Review ^[\(engine.lastResultCount) Group](inflect: true)")
        }
    }

    /// Confirms how many photos the AI/content filter matched, so a "no
    /// duplicates" result is distinguishable from "no photos matched".
    @ViewBuilder
    private func contentMatchNote(query: String) -> some View {
        if engine.scannedCount > 0 {
            Label("Found ^[\(engine.scannedCount) photo](inflect: true) matching “\(query)”.",
                  systemImage: "sparkle.magnifyingglass")
        } else {
            Label("No photos matched “\(query)”.", systemImage: "sparkle.magnifyingglass")
        }
    }
}

private struct StageRow: View {
    let stage: ScanStage
    let current: ScanStage?
    let finished: Bool

    var body: some View {
        Label {
            Text(stage.rawValue)
                .foregroundStyle(isActive ? .primary : .secondary)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(isComplete ? Color.green : (isActive ? Color.accentColor : Color.secondary))
        }
        .font(.subheadline)
    }

    private var order: Int { ScanStage.allCases.firstIndex(of: stage) ?? 0 }
    private var currentOrder: Int { current.flatMap { ScanStage.allCases.firstIndex(of: $0) } ?? (finished ? ScanStage.allCases.count : -1) }
    private var isActive: Bool { current == stage }
    private var isComplete: Bool { finished || order < currentOrder }

    private var symbol: String {
        if isComplete { return "checkmark.circle.fill" }
        if isActive { return "circle.dotted" }
        return "circle"
    }
}
