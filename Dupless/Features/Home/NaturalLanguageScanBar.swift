import SwiftUI

/// The optional in-app natural-language input ("find similar photos from last
/// weekend"). Parses on submit and presents a resolved-settings confirmation
/// before anything runs. Falls back to template parsing when the model is off.
struct NaturalLanguageScanBar: View {
    @State private var model = NaturalLanguageScanModel()

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            TextField("Describe what to scan…", text: $model.query, axis: .vertical)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit(submit)
            if model.isParsing {
                ProgressView()
                    .accessibilityLabel("Working on it")
            } else {
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.canSubmit ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                .disabled(!model.canSubmit)
                .accessibilityLabel("Scan")
            }
        }
        .sheet(isPresented: presentingConfirmation) {
            if let pending = model.pending {
                ScanConfirmationView(
                    summary: pending.summary,
                    understood: pending.understood,
                    source: pending.source,
                    locationQuery: pending.command.locationQuery,
                    onScan: { model.confirm() },
                    onCancel: { model.cancel() }
                )
                .presentationDetents([.medium])
            }
        }
    }

    private func submit() {
        Task { await model.submit() }
    }

    private var presentingConfirmation: Binding<Bool> {
        Binding(
            get: { model.pending != nil },
            set: { if !$0 { model.cancel() } }
        )
    }
}

/// Shows the resolved scan settings for the user to confirm before scanning —
/// the spec's mitigation against the model misreading a request.
private struct ScanConfirmationView: View {
    let summary: String
    let understood: Bool
    let source: ParsedScan.Source
    var locationQuery: String?
    let onScan: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("locationMatchingEnabled") private var locationMatching = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Here's what I'll scan", systemImage: "sparkle.magnifyingglass")
                .font(.headline)

            Text(summary)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

            Label(source.label, systemImage: source.systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel(source.label)

            if let place = locationQuery {
                locationOptIn(place: place)
            }

            if !understood {
                Label("I wasn't sure about parts of that, so I used safe defaults. You can adjust after scanning.",
                      systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("Nothing is deleted — you'll review everything first.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Button("Cancel", role: .cancel) { onCancel(); dismiss() }
                    .frame(maxWidth: .infinity)
                Button {
                    onScan(); dismiss()
                } label: {
                    Text("Scan").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
        .padding()
    }

    /// Opt-in for matching a place by location — the one networked step, so it's
    /// off by default and clearly disclosed.
    @ViewBuilder
    private func locationOptIn(place: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $locationMatching) {
                Text("Find \(place) photos by location")
                    .font(.subheadline)
            }
            Text("Looks up where photos were taken using Apple's location service — the only time Dupless sends data (coordinates, never your photos) off your device. Off keeps everything on-device.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
