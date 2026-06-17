import SwiftUI

/// Final confirmation before moving photos to Recently Deleted
/// (CleanupConfirmationView). Uses the safe, reassuring language the spec
/// mandates. The actual deletion still triggers PhotoKit's own system prompt.
struct CleanupConfirmationView: View {
    let count: Int
    let onConfirm: () async -> PhotoMutationService.Result

    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 52))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.red)
                .padding(.top, 8)

            Text("Move \(count) photo\(count == 1 ? "" : "s") to Recently Deleted?")
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            Text("You can review and restore them in the Photos app for 30 days. Nothing is permanently removed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 12) {
                Button(role: .destructive) {
                    confirm()
                } label: {
                    Group {
                        if isWorking {
                            ProgressView()
                        } else {
                            Text("Move to Recently Deleted")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isWorking)

                Button("Cancel") { dismiss() }
                    .disabled(isWorking)
            }
        }
        .padding()
        .interactiveDismissDisabled(isWorking)
    }

    private func confirm() {
        isWorking = true
        errorMessage = nil
        Task {
            let result = await onConfirm()
            isWorking = false
            switch result {
            case .success:
                dismiss()
            case .cancelled:
                dismiss()
            case .failed(let message):
                errorMessage = message
            }
        }
    }
}
