import BruskCore
import MapKit
import PhotosUI
import SwiftUI

/// Screen 2 (spec §5): report in three steps, under 20 seconds.
struct ReportFlowView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model = ReportViewModel()
    @State private var isConfirmingDiscard = false
    @State private var isShowingHelp = false

    var body: some View {
        NavigationStack {
            Group {
                if let submitted = model.submitted {
                    ReportDoneView(category: model.category ?? .road, status: submitted.status, onHelp: { isShowingHelp = true }) {
                        dismiss()
                    }
                    .transition(.opacity)
                } else {
                    stepContent
                        .safeAreaInset(edge: .top, spacing: 0) {
                            StepIndicator(current: model.step.rawValue, total: ReportViewModel.Step.allCases.count)
                                .padding(.horizontal, Space.gutter)
                                .padding(.vertical, Space.s)
                        }
                        .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
                }
            }
            .background(Color.ds(.background))
            .navigationTitle(model.submitted == nil ? Text(model.step.titleKey) : Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .interactiveDismissDisabled(model.hasInput && model.submitted == nil)
        .confirmationDialog(Text("report.discard.title"), isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
            Button(role: .destructive) { dismiss() } label: { Text("report.discard.confirm") }
        }
        .sheet(isPresented: $isShowingHelp) {
            NavigationStack { HelpScreen(isModal: true) }
        }
        .haptic(.success, trigger: model.submitted != nil)
        .dsAnimation(Motion.standard, value: model.submitted != nil)
    }

    // MARK: Steps

    @ViewBuilder
    private var stepContent: some View {
        ZStack {
            switch model.step {
            case .what:
                WhatStep(model: model, onHelp: { isShowingHelp = true })
                    .transition(stepTransition)
            case .whereWhen:
                WhereWhenStep(model: model, onHelp: { isShowingHelp = true })
                    .transition(stepTransition)
            case .details:
                DetailsStep(model: model)
                    .transition(stepTransition)
            }
        }
        .dsAnimation(Motion.standard, value: model.step)
    }

    private var stepTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity))
    }

    private var actionBar: some View {
        VStack(spacing: Space.s) {
            if let error = model.submitError {
                Banner(kind: .warning, titleKey: LocalizedStringKey(error.messageKey))
            }
            if model.step == .details {
                DSButton("common.send", systemImage: "paperplane.fill", isLoading: model.isSubmitting) {
                    Task { await model.submit(backend: environment.backend, store: environment.store) }
                }
                .disabled(!model.canContinue)
            } else {
                DSButton("common.continue") {
                    model.advance()
                }
                .disabled(!model.canContinue)
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.s)
        .padding(.bottom, Space.s)
        .background(.bar)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if model.submitted == nil {
                Button {
                    if model.hasInput { isConfirmingDiscard = true } else { dismiss() }
                } label: {
                    Text("common.cancel")
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if model.step > .what, model.submitted == nil {
                Button { model.back() } label: { Text("common.back") }
            }
        }
    }
}

// MARK: - Step 1: What?

private struct WhatStep: View {
    let model: ReportViewModel
    let onHelp: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var selectionTick = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                Text("report.what.subtitle")
                    .textStyle(.body)
                    .foregroundStyle(Color.ds(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: columns, spacing: Space.s + Space.xs) {
                    ForEach(ReportCategory.allCases) { category in
                        CategoryTile(category: category, isSelected: model.category == category) {
                            selectionTick += 1
                            // Auto-advance would move VoiceOver focus unexpectedly: users advance with Continue.
                            if model.choose(category), !voiceOverEnabled {
                                Task {
                                    try? await Task.sleep(for: .milliseconds(280))
                                    model.advance()
                                }
                            }
                        }
                    }
                }

                if let category = model.category, category.isSerious {
                    SeriousFactsBanner(onHelp: onHelp)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(Space.gutter)
            .dsAnimation(Motion.standard, value: model.category)
        }
        .haptic(.selection, trigger: selectionTick)
    }

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: Space.s + Space.xs, alignment: .top), count: count)
    }
}

/// Help first (spec §4.4): shown as soon as theft/aggression or harassment is chosen.
struct SeriousFactsBanner: View {
    let onHelp: () -> Void
    @Environment(\.openURL) private var openURL
    @State private var appeared = false

    var body: some View {
        Banner(kind: .serious, titleKey: "report.serious.title", messageKey: "report.serious.message") {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.s) { buttons }
                VStack(spacing: Space.s) { buttons }
            }
        }
        .onAppear { appeared = true }
        .haptic(.warning, trigger: appeared)
    }

    @ViewBuilder
    private var buttons: some View {
        DSButton("report.serious.call112", systemImage: "phone.fill", kind: .destructive) {
            if let url = EmergencyDirectory.emergency.telURL { openURL(url) }
        }
        DSButton("report.serious.help", systemImage: "cross.case", kind: .secondary, action: onHelp)
    }
}

// MARK: - Step 2: Where and when?

private struct WhereWhenStep: View {
    @Bindable var model: ReportViewModel
    let onHelp: () -> Void
    @Environment(AppEnvironment.self) private var environment
    @Environment(LanguageStore.self) private var language
    @ScaledMetric(relativeTo: .body) private var mapHeight: CGFloat = 320
    @ScaledMetric(relativeTo: .title) private var pinSize: CGFloat = 36

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                if let category = model.category, category.isSerious {
                    SeriousFactsBanner(onHelp: onHelp)
                }

                ZStack {
                    Map(position: $model.camera, interactionModes: [.pan, .zoom]) {
                        UserAnnotation()
                    }
                    .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
                    .onMapCameraChange(frequency: .onEnd) { context in
                        model.setPin(GeoCoordinate(context.region.center), locale: language.locale)
                    }
                    .accessibilityLabel(Text("report.where.map.a11y"))

                    // Fixed centre pin: the map moves underneath it.
                    Image(systemName: "mappin")
                        .font(.system(size: pinSize, weight: .semibold))
                        .foregroundStyle(model.category?.color ?? Color.ds(.accent))
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                        .offset(y: -pinSize / 2) // the pin's tip marks the map centre
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                    if model.isLocating {
                        ProgressView()
                            .padding(Space.m)
                            .glassSurface(in: Circle())
                    }
                }
                .frame(height: min(mapHeight, 420))
                .clipShape(Radius.shape(Radius.large))

                placeLine

                if model.locationUnavailable {
                    Banner(kind: .info, titleKey: "report.where.noLocation.title", messageKey: "report.where.noLocation.message")
                }
                ForEach(Array(model.placeIssues), id: \.self) { issue in
                    Banner(kind: .warning, titleKey: LocalizedStringKey(issue.messageKey))
                }

                VStack(alignment: .leading, spacing: Space.s) {
                    Text("report.when.title")
                        .textStyle(.headline)
                        .foregroundStyle(Color.ds(.textPrimary))
                    DatePicker(selection: $model.occurredAt, in: model.earliestDate...Date(), displayedComponents: [.date, .hourAndMinute]) {
                        Text("report.when.label")
                            .textStyle(.body)
                            .foregroundStyle(Color.ds(.textSecondary))
                    }
                    .tint(Color.ds(.accent))
                }
                .padding(Space.m)
                .cardSurface(radius: Radius.medium)
            }
            .padding(Space.gutter)
        }
        .task { await model.locate(with: environment.location, locale: language.locale) }
    }

    private var placeLine: some View {
        Label {
            if let street = model.streetName {
                Text("zone.nearStreet \(street)")
            } else {
                Text("report.where.dragHint")
            }
        } icon: {
            Image(systemName: "hand.draw")
        }
        .textStyle(.subheadline)
        .foregroundStyle(Color.ds(.textSecondary))
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Step 3: Details

private struct DetailsStep: View {
    @Bindable var model: ReportViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @FocusState private var noteFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                photoSection
                noteSection
                Label("report.details.privacy", systemImage: "hand.raised")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.ds(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.gutter)
        }
        .scrollDismissesKeyboard(.interactively)
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { image in
                Task { await model.attach(image) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await model.attach(image)
                }
                pickerItem = nil
            }
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("report.photo.title")
                    .textStyle(.headline)
                    .foregroundStyle(Color.ds(.textPrimary))
                Text("common.optional")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.ds(.textTertiary))
            }

            if model.isProcessingPhoto {
                HStack(spacing: Space.s + Space.xs) {
                    ProgressView()
                    Text("report.photo.processing")
                        .textStyle(.subheadline)
                        .foregroundStyle(Color.ds(.textSecondary))
                }
                .frame(maxWidth: .infinity, minHeight: 160)
                .cardSurface(radius: Radius.medium)
            } else if let photo = model.photo {
                VStack(alignment: .leading, spacing: Space.s) {
                    Image(uiImage: photo.preview)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 240)
                        .clipShape(Radius.shape(Radius.medium))
                        .accessibilityLabel(Text("report.photo.preview.a11y"))
                    Label {
                        if photo.facesBlurred + photo.platesBlurred == 0 {
                            Text("report.photo.nothingFound")
                        } else {
                            Text("report.photo.blurred \(photo.facesBlurred + photo.platesBlurred)")
                        }
                    } icon: {
                        Image(systemName: "eye.slash")
                    }
                    .textStyle(.footnote)
                    .foregroundStyle(Color.ds(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                    Text("report.photo.originalStaysHere")
                        .textStyle(.footnote)
                        .foregroundStyle(Color.ds(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                    DSButton("report.photo.remove", systemImage: "trash", kind: .tertiary, fullWidth: false) {
                        model.removePhoto()
                    }
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Space.s) { photoButtons }
                    VStack(spacing: Space.s) { photoButtons }
                }
                Text("report.photo.blurPromise")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.ds(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                if model.photoFailed {
                    Banner(kind: .warning, titleKey: "report.photo.failed")
                }
            }
        }
    }

    @ViewBuilder
    private var photoButtons: some View {
        if CameraPicker.isAvailable {
            DSButton("report.photo.take", systemImage: "camera", kind: .secondary) { isShowingCamera = true }
        }
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            Label("report.photo.choose", systemImage: "photo.on.rectangle")
        }
        .buttonStyle(DSButtonStyle(kind: .secondary))
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("report.note.title")
                    .textStyle(.headline)
                    .foregroundStyle(Color.ds(.textPrimary))
                Text("common.optional")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.ds(.textTertiary))
                Spacer()
                Text("report.note.counter \(model.note.count) \(TextGuard.maxLength)")
                    .textStyle(.caption)
                    .monospacedDigit()
                    .foregroundStyle(model.note.count > TextGuard.maxLength ? Color.ds(.categoryInsecurity) : Color.ds(.textTertiary))
            }
            TextField(text: $model.note, prompt: Text("report.note.placeholder"), axis: .vertical) {
                Text("report.note.title")
            }
            .lineLimit(3...6)
            .focused($noteFocused)
            .textStyle(.body)
            .padding(Space.m)
            .cardSurface(radius: Radius.medium)
            .overlay(Radius.shape(Radius.medium).strokeBorder(model.textIssues.isEmpty ? Color.clear : Color.ds(.categoryRoad), lineWidth: 1.5))

            ForEach(Array(model.textIssues).sorted { $0.rawValue < $1.rawValue }, id: \.self) { issue in
                Banner(kind: .warning, titleKey: LocalizedStringKey(issue.messageKey))
            }
        }
        .dsAnimation(Motion.quick, value: model.textIssues)
    }
}

// MARK: - Done

struct ReportDoneView: View {
    let category: ReportCategory
    let status: ReportStatus
    let onHelp: () -> Void
    let onDone: () -> Void
    @State private var appeared = false
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 64

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: heroSize, weight: .semibold))
                    .foregroundStyle(Color.ds(.statusResolved))
                    .symbolEffect(.bounce, value: appeared)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("report.done.title")
                        .textStyle(.display)
                        .foregroundStyle(Color.ds(.textPrimary))
                        .accessibilityAddTraits(.isHeader)
                    Text("report.done.message")
                        .textStyle(.body)
                        .foregroundStyle(Color.ds(.textSecondary))
                }
                .fixedSize(horizontal: false, vertical: true)
                StatusTimeline(status: status)
                    .padding(Space.m)
                    .cardSurface()
                if category.isSerious {
                    Banner(kind: .info, titleKey: "report.done.serious.title", messageKey: "report.done.serious.message") {
                        DSButton("report.serious.help", systemImage: "cross.case", kind: .secondary, action: onHelp)
                    }
                }
                DSButton("common.done", action: onDone)
            }
            .padding(Space.gutter)
        }
        .onAppear { appeared = true }
    }
}

#Preview("Report flow") {
    let environment = AppEnvironment.preview()
    ReportFlowView()
        .environment(environment)
        .environment(environment.language)
}

#Preview("Report flow — dark, Dutch, AX5") {
    let environment = AppEnvironment.preview()
    ReportFlowView()
        .environment(environment)
        .environment(environment.language)
        .environment(\.locale, Locale(identifier: "nl_BE"))
        .previewAccessibilitySize()
        .preferredColorScheme(.dark)
}

#Preview("Done — serious, French") {
    ReportDoneView(category: .harassment, status: .pending, onHelp: {}, onDone: {})
        .environment(\.locale, Locale(identifier: "fr_BE"))
        .background(Color.ds(.background))
}
