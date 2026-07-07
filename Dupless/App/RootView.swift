import SwiftUI

/// Routes between onboarding (no access yet) and the main app (access granted).
/// Shows a brief launch screen first so a cold start has visible feedback while
/// authorization resolves and the store warms up. Refreshes authorization when
/// the app returns to the foreground so revoked permissions are reflected.
struct RootView: View {
    @Environment(PhotoAuthorizationManager.self) private var authorization
    @Environment(\.scenePhase) private var scenePhase

    @State private var isReady = false

    var body: some View {
        ZStack {
            if isReady {
                content
                    .transition(.opacity)
            } else {
                LaunchView()
                    .transition(.opacity)
            }
        }
        .task {
            // Resolve access and give the launch bar a beat to show on a cold
            // start, then reveal the main UI.
            authorization.refresh()
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeOut(duration: 0.35)) { isReady = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { authorization.refresh() }
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if authorization.status.grantsAccess {
                HomeView()
            } else {
                PhotoAccessView()
            }
        }
        .animation(.default, value: authorization.status)
    }
}

/// Launch screen shown briefly on cold start: app mark, name, and a progress bar
/// that fills as the app comes up.
private struct LaunchView: View {
    @State private var progress: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Dupless")
                .font(.largeTitle.bold())
            Spacer()
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 200)
                .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dupless, loading")
        .task {
            withAnimation(.easeInOut(duration: 0.85)) { progress = 1 }
        }
    }
}

