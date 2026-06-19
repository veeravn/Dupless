import SwiftData
import SwiftUI

/// Main landing screen. Surfaces Scan, Review, last-scan status. Navigation is
/// path-based so App Intents / Siri can drive it via `IntentRouter`.
struct HomeView: View {
    @Environment(PhotoAuthorizationManager.self) private var authorization
    @Environment(ScanEngine.self) private var scanEngine
    @Environment(IntentRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query private var groups: [DuplicateGroupRecord]
    @Query(filter: #Predicate<ScanCheckpointRecord> { !$0.isComplete })
    private var incompleteScans: [ScanCheckpointRecord]
    @AppStorage(ScanEngine.lastScanDateKey) private var lastScanDate: Double = 0

    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if authorization.status == .limited {
                    Section { LimitedAccessBanner() }
                }

                if let interrupted = incompleteScans.first, !scanEngine.isScanning {
                    Section {
                        NavigationLink(value: AppRoute.resume) {
                            ResumeScanLabel(checkpoint: interrupted)
                        }
                    }
                }

                Section("Ask CleanShots") {
                    NaturalLanguageScanBar()
                }

                Section("Get started") {
                    NavigationLink(value: AppRoute.scanSetup) {
                        Label("Scan Photos", systemImage: "sparkle.magnifyingglass")
                    }
                    NavigationLink(value: AppRoute.droneBurstScan(scope: .recent(limit: 300), options: .default)) {
                        Label("Drone / Burst Mode", systemImage: "airplane")
                    }
                    NavigationLink(value: AppRoute.review) {
                        Label("Review Duplicates", systemImage: "rectangle.stack.badge.minus")
                    }
                    .disabled(groups.isEmpty)
                    NavigationLink(value: AppRoute.browse) {
                        Label("Browse Photos", systemImage: "photo.on.rectangle")
                    }
                }

                Section("Last scan") {
                    LabeledContent("Status", value: statusText)
                    LabeledContent("Estimated duplicates", value: duplicatesText)
                }
            }
            .navigationTitle("CleanShots")
            .navigationDestination(for: AppRoute.self, destination: destination)
        }
        .onChange(of: router.route, initial: true) { _, route in
            guard let route else { return }
            path = [route]
            router.route = nil
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .scanSetup:
            ScanSetupView()
        case .scan(let request):
            ScanProgressView(job: .fresh(scope: request.scope, options: request.options, sensitivity: request.sensitivity))
        case let .droneBurstScan(scope, options):
            ScanProgressView(job: .droneBurst(scope: scope, options: options))
        case .review:
            DuplicateGroupListView()
        case .resume:
            ResumeDestination()
        case .browse:
            PhotoGridView()
        }
    }

    private var statusText: String {
        guard lastScanDate > 0 else { return "No scans yet" }
        return Date(timeIntervalSince1970: lastScanDate).formatted(.relative(presentation: .named))
    }

    private var duplicatesText: String {
        guard !groups.isEmpty else { return "—" }
        let removable = groups.reduce(0) { $0 + $1.estimatedRemovableCount }
        return "\(removable) photos"
    }
}

/// Resolves the latest interrupted scan and resumes it, or falls back to review.
private struct ResumeDestination: View {
    @Environment(ScanEngine.self) private var scanEngine
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let checkpoint = scanEngine.incompleteCheckpoint(in: modelContext) {
            ScanProgressView(job: .resume(checkpoint))
        } else {
            DuplicateGroupListView()
        }
    }
}

private struct ResumeScanLabel: View {
    let checkpoint: ScanCheckpointRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Resume Scan", systemImage: "arrow.clockwise.circle")
                .font(.headline)
            Text("Your last scan of \(checkpoint.scopeDescription) was interrupted. Pick up where it left off.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// Shown when the user granted limited access; offers the "Add More Photos" flow.
private struct LimitedAccessBanner: View {
    @Environment(PhotoAuthorizationManager.self) private var authorization

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Limited Photos Access", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text("CleanShots can only see the photos you've selected. Add more so it can find duplicates across your library.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Add More Photos") { presentPicker() }
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }

    private func presentPicker() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController else { return }
        authorization.presentLimitedLibraryPicker(from: root)
    }
}
