//
//  ImageAssistReviewView.swift
//  neighbourly
//
//  The "Suggest details" section of the Create Listing form. Shows what
//  on-device analysis found as suggestions the user can apply or dismiss.
//

import SwiftUI

struct ImageAssistReviewView: View {
    let viewModel: CreateListingViewModel

    var body: some View {
        Section {
            switch viewModel.assistState {
            case .idle:
                suggestButton

            case .analyzing:
                HStack(spacing: Theme.Spacing.m) {
                    ProgressView()
                    Text("Analysing photo on your device…")
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
                .accessibilityElement(children: .combine)

            case .result(let suggestions):
                resultContent(suggestions)

            case .noResult:
                message("Nothing useful was found in this photo. You can fill in the details yourself.", systemImage: "questionmark.circle")
                suggestButton
                dismissButton

            case .failed(let reason):
                message(reason, systemImage: "exclamationmark.triangle")
                suggestButton
                dismissButton
            }
        } header: {
            Text("Suggestions")
        } footer: {
            Text(footerText)
        }
    }

    private var footerText: String {
        if viewModel.photos.isEmpty {
            return "Add a photo to get suggestions. Analysis runs on your device — nothing is uploaded — and results can be wrong, so always check them."
        }
        return "A pretrained image model (MobileNetV2) and text recognition run on your device — nothing is uploaded. Results can be wrong, so check them before using. Based on your first photo."
    }

    // MARK: - Pieces

    private var suggestButton: some View {
        Button {
            Task { await viewModel.suggestDetails() }
        } label: {
            Label("Suggest Details", systemImage: "sparkles")
        }
        .disabled(viewModel.photos.isEmpty)
    }

    private var dismissButton: some View {
        Button("Dismiss", role: .cancel) { viewModel.dismissSuggestions() }
    }

    private func message(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(Theme.Typography.subheadline)
            .foregroundStyle(Theme.Colors.secondaryText)
    }

    @ViewBuilder
    private func resultContent(_ suggestions: ImageSuggestions) -> some View {
        // Category
        if suggestions.classificationUnavailable {
            message(
                "Couldn't identify the item type, so pick a category yourself. The text found in the photo can still help.",
                systemImage: "questionmark.circle"
            )
        } else {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Suggested category")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                Label(suggestions.category.displayName, systemImage: suggestions.category.systemImage)
            }
            Spacer()
            if viewModel.category == suggestions.category {
                Label("Selected", systemImage: "checkmark")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            } else {
                Button("Use") { viewModel.applySuggestedCategory(suggestions.category) }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Use \(suggestions.category.displayName) as category")
            }
        }
        }

        // Labels (informational)
        if !suggestions.labels.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Looks like")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                Text(verbatim: suggestions.labels.joined(separator: " · "))
            }
            .accessibilityElement(children: .combine)
        }

        if !suggestions.allLabels.isEmpty {
            DisclosureGroup("All detected labels (model guesses)") {
                Text(verbatim: suggestions.allLabels.joined(separator: ", "))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            .font(Theme.Typography.caption)
        }

        // Recognised text. Shown verbatim and never applied automatically; there is
        // deliberately no "use as price" or "use as contact" action.
        if !suggestions.textLines.isEmpty {
            Text("Text found in photo")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.secondaryText)

            ForEach(suggestions.textLines, id: \.self) { line in
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text(verbatim: line)
                    HStack(spacing: Theme.Spacing.s) {
                        Button("Use as title") { viewModel.useAsTitle(line) }
                        Button("Add to description") { viewModel.appendToDescription(line) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
        }

        dismissButton
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    Form {
        ImageAssistReviewView(
            viewModel: CreateListingViewModel(
                repository: dependencies.listingRepository,
                photoStore: dependencies.photoStore
            )
        )
    }
}
