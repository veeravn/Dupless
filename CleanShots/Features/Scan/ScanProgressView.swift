import SwiftUI
import SwiftData

/// The work a progress screen performs: a fresh scan or a resumed one.
enum ScanJob {
    case fresh(scope: ScanScope, options: ScanOptions, sensitivity: SimilaritySensitivity)
    case resume(ScanCheckpointRecord)
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

            if finished {
                NavigationLink {
                    DuplicateGroupListView()
                } label: {
                    Text(engine.lastResultCount > 0 ? "Review ^[\(engine.lastResultCount) Group](inflect: true)" : "No Duplicates Found")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 40)
            }
        }
        .padding()
        .navigationTitle("Scanning")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(engine.isScanning)
        .interactiveDismissDisabled(engine.isScanning)
        .task {
            guard !finished else { return }
            switch job {
            case let .fresh(scope, options, sensitivity):
                await engine.scan(scope: scope, options: options, sensitivity: sensitivity, modelContext: modelContext)
            case let .resume(checkpoint):
                await engine.resume(checkpoint: checkpoint, modelContext: modelContext)
            }
            finished = true
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
