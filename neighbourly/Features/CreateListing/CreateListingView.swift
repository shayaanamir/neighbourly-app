//
//  CreateListingView.swift
//  neighbourly
//
//  Sheet form for adding a listing, or editing one of your own when `editing` is set.
//

import PhotosUI
import SwiftUI

struct CreateListingView: View {
    @State private var viewModel: CreateListingViewModel
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false
    @State private var showDiscardDialog = false

    @Environment(\.dismiss) private var dismiss
    private let onSaved: (Listing) -> Void

    init(
        repository: any ListingRepository,
        photoStore: PhotoStore,
        visionAssist: any VisionAssisting,
        editing listing: Listing? = nil,
        defaultSellerName: String? = nil,
        sellerID: String? = nil,
        onSaved: @escaping (Listing) -> Void
    ) {
        _viewModel = State(initialValue: CreateListingViewModel(
            repository: repository,
            photoStore: photoStore,
            visionAssist: visionAssist,
            editing: listing,
            defaultSellerName: defaultSellerName,
            sellerID: sellerID
        ))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                photosSection
                ImageAssistReviewView(viewModel: viewModel)
                detailsSection
                offerSection
                sellerSection
            }
            .navigationTitle(viewModel.isEditing ? "Edit Listing" : "New Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                        .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .fontWeight(.semibold)
                    }
                }
            }
            .task { await viewModel.loadExistingPhotos() }
            .interactiveDismissDisabled(viewModel.isDirty || viewModel.isSaving)
            .confirmationDialog(viewModel.isEditing ? "Discard your changes?" : "Discard this listing?", isPresented: $showDiscardDialog, titleVisibility: .visible) {
                Button(viewModel.isEditing ? "Discard Changes" : "Discard Listing", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Your changes haven't been saved.")
            }
            .alert("Couldn't save listing", isPresented: saveErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.saveError ?? "")
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await loadPhotos(items) }
            }
        }
        .disabled(viewModel.isSaving)
    }

    // MARK: - Sections

    private var photosSection: some View {
        Section {
            if !viewModel.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.m) {
                        ForEach(Array(viewModel.photos.enumerated()), id: \.element.id) { index, photo in
                            photoPreview(photo, number: index + 1)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }

            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: max(1, viewModel.remainingPhotoSlots),
                matching: .images
            ) {
                HStack {
                    Label(viewModel.photos.isEmpty ? "Add Photos" : "Add More Photos", systemImage: "photo.on.rectangle.angled")
                    if isLoadingPhotos {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.remainingPhotoSlots == 0 || isLoadingPhotos)

            if let message = viewModel.photoMessage {
                Text(message)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Photos")
        } footer: {
            Text("Up to \(CreateListingViewModel.maxPhotos) photos. Optional, but listings with photos are easier to browse.")
        }
    }

    private func photoPreview(_ photo: CreateListingViewModel.SelectedPhoto, number: Int) -> some View {
        Image(uiImage: photo.thumbnail)
            .resizable()
            .scaledToFill()
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s))
            .overlay(alignment: .topTrailing) {
                Button {
                    viewModel.removePhoto(id: photo.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                        .padding(4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove photo \(number)")
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Photo \(number)")
    }

    private var detailsSection: some View {
        Section("Details") {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                TextField("Title", text: $viewModel.title)
                    .textInputAutocapitalization(.sentences)
                HStack {
                    errorText(viewModel.visibleErrors.title)
                    Spacer()
                    Text("\(viewModel.title.count)/\(Listing.maxTitleLength)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(viewModel.title.count > Listing.maxTitleLength ? Color.red : Theme.Colors.secondaryText)
                        .accessibilityHidden(true)
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                TextField("Description (optional)", text: $viewModel.description, axis: .vertical)
                    .lineLimit(3...8)
                HStack {
                    errorText(viewModel.visibleErrors.description)
                    Spacer()
                    Text("\(viewModel.description.count)/\(Listing.maxDescriptionLength)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(viewModel.description.count > Listing.maxDescriptionLength ? Color.red : Theme.Colors.secondaryText)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private var offerSection: some View {
        Section("Offer") {
            Picker("Listing type", selection: $viewModel.mode) {
                ForEach(ListingMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.mode.requiresPrice {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack {
                        Text("₹")
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .accessibilityHidden(true)
                        TextField("Price", text: $viewModel.priceInput)
                            .keyboardType(.decimalPad)
                            .accessibilityLabel("Price in rupees")
                    }
                    errorText(viewModel.visibleErrors.price)
                }
            } else {
                Text(viewModel.mode == .donate
                     ? "Donations are free — no price needed."
                     : "Exchange listings don't have a price. Describe what you'd like in return.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            Picker("Category", selection: $viewModel.category) {
                ForEach(ListingCategory.allCases) { category in
                    Label(category.displayName, systemImage: category.systemImage).tag(category)
                }
            }

            Picker("Condition", selection: $viewModel.condition) {
                ForEach(ItemCondition.allCases) { condition in
                    Text(condition.displayName).tag(condition)
                }
            }
        }
    }

    private var sellerSection: some View {
        Section {
            TextField("Area or neighbourhood (optional)", text: $viewModel.areaName)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                TextField("Your name", text: $viewModel.sellerName)
                    .textContentType(.name)
                errorText(viewModel.visibleErrors.sellerName)
            }

        } header: {
            Text("Seller")
        } footer: {
            Text("Use a general area, not your street address. Buyers contact you through in-app chat, so there is no need to share an email or phone number.")
        }
    }

    @ViewBuilder
    private func errorText(_ message: String?) -> some View {
        if let message {
            Label(message, systemImage: "exclamationmark.circle")
                .font(Theme.Typography.caption)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Actions

    private func cancel() {
        if viewModel.isDirty {
            showDiscardDialog = true
        } else {
            dismiss()
        }
    }

    private func save() async {
        // Make sure the keyboard doesn't cover the inline errors.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        if let listing = await viewModel.save() {
            onSaved(listing)
            dismiss()
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        defer {
            isLoadingPhotos = false
            pickerItems = []
        }
        var datas: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                datas.append(data)
            }
        }
        if datas.count < items.count {
            viewModel.photoMessage = "Some photos couldn't be loaded."
        }
        await viewModel.addPhotos(datas)
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.saveError != nil },
            set: { if !$0 { viewModel.saveError = nil } }
        )
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    CreateListingView(
        repository: dependencies.listingRepository,
        photoStore: dependencies.photoStore,
        visionAssist: dependencies.visionAssist,
        onSaved: { _ in }
    )
}
