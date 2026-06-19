import SwiftData
import SwiftUI

/// Main landing screen. On iPhone (compact width) it's a path-based
/// `NavigationStack`; on iPad (regular width) a `NavigationSplitView` with a
/// sidebar of actions and a detail pane. Both share the same `path`,
/// `destination(for:)`, and App-Intent routing, so Siri drives either layout.
struct HomeView: View {
    @Environment(PhotoAuthorizationManager.self) private var authorization
    @Environment(ScanEngine.self) private var scanEngine
    @Environment(IntentRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query private var groups: [DuplicateGroupRecord]
    @Query(filter: #Predicate<ScanCheckpointRecord> { !$0.isComplete })
    private var incompleteScans: [ScanCheckpointRecord]
    @AppStorage(ScanEngine.lastScanDateKey) private var lastScanDate: Double = 0

    @State private var path: [AppRoute] = []
    @State private var sidebarSelection: SidebarItem?

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .onChange(of: router.route, initial: true) { _, route in
            guard let route else { return }
            path = [route]
            router.route = nil
        }
    }

    // MARK: - iPhone (unchanged)

    private var iPhoneLayout: some View {
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
                    NavigationLink(value: AppRoute.droneBurstSetup) {
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
    }

    // MARK: - iPad

    private var iPadLayout: some View {
        NavigationSplitView {
            List(selection: $sidebarSelection) {
                if authorization.status == .limited {
                    Section { LimitedAccessBanner() }
                }

                Section("Ask CleanShots") {
                    NaturalLanguageScanBar()
                }

                if let interrupted = incompleteScans.first, !scanEngine.isScanning {
                    Section {
                        Button { path = [.resume] } label: { ResumeScanLabel(checkpoint: interrupted) }
                            .buttonStyle(.plain)
                    }
                }

                Section("Get started") {
                    Label("Scan Photos", systemImage: "sparkle.magnifyingglass").tag(SidebarItem.scan)
                    Label("Drone / Burst Mode", systemImage: "airplane").tag(SidebarItem.droneBurst)
                    Label("Review Duplicates", systemImage: "rectangle.stack.badge.minus")
                        .tag(SidebarItem.review)
                        .disabled(groups.isEmpty)
                    Label("Browse Photos", systemImage: "photo.on.rectangle").tag(SidebarItem.browse)
                }

                Section("Last scan") {
                    LabeledContent("Status", value: statusText)
                    LabeledContent("Estimated duplicates", value: duplicatesText)
                }
            }
            .navigationTitle("CleanShots")
        } detail: {
            NavigationStack(path: $path) {
                WelcomeDetail()
                    .navigationDestination(for: AppRoute.self, destination: destination)
            }
        }
        .onChange(of: sidebarSelection) { _, item in
            guard let item else { return }
            path = [item.route]
        }
        .onChange(of: path) { _, newPath in
            // Returning to the welcome pane clears the highlight so the same item
            // can be re-selected.
            if newPath.isEmpty { sidebarSelection = nil }
        }
    }

    // MARK: - Shared

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .scanSetup:
            ScanSetupView()
        case .scan(let request):
            ScanProgressView(job: .fresh(scope: request.scope, options: request.options, sensitivity: request.sensitivity))
        case .droneBurstSetup:
            DroneBurstSetupView()
        case let .droneBurstScan(scope, options, droneOptions):
            ScanProgressView(job: .droneBurst(scope: scope, options: options, droneOptions: droneOptions))
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

/// Sidebar actions on iPad, each mapping to the route shown in the detail pane.
enum SidebarItem: Hashable {
    case scan, droneBurst, review, browse

    var route: AppRoute {
        switch self {
        case .scan: return .scanSetup
        case .droneBurst: return .droneBurstSetup
        case .review: return .review
        case .browse: return .browse
        }
    }
}

/// Placeholder shown in the iPad detail pane before an action is chosen.
private struct WelcomeDetail: View {
    var body: some View {
        ContentUnavailableView {
            Label("CleanShots", systemImage: "sparkles")
        } description: {
            Text("Choose Scan, Drone / Burst, or Review to begin. Everything happens on your device.")
        }
        .navigationTitle("CleanShots")
        .navigationBarTitleDisplayMode(.inline)
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
