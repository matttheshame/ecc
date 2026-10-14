import BruskBackend
import BruskCore
import MapKit
import Observation
import SwiftUI
import UIKit

/// Report flow state (spec §5 écran 2): What → Where/When → Details, under 20 s.
@MainActor
@Observable
final class ReportViewModel {
    enum Step: Int, CaseIterable, Comparable {
        case what = 1
        case whereWhen
        case details

        static func < (lhs: Step, rhs: Step) -> Bool { lhs.rawValue < rhs.rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .what: "report.what.title"
            case .whereWhen: "report.where.title"
            case .details: "report.details.title"
            }
        }
    }

    var step: Step = .what
    private(set) var category: ReportCategory?

    // Where & when
    var camera: MapCameraPosition = .region(MapViewModel.brusselsRegion)
    private(set) var coordinate: GeoCoordinate?
    private(set) var streetName: String?
    private(set) var isLocating = false
    private(set) var locationUnavailable = false
    var occurredAt = Date()

    // Details
    var note = ""
    private(set) var photo: AnonymisedPhoto?
    /// The unblurred original. Saved on this device only, never uploaded.
    private(set) var originalJPEG: Data?
    private(set) var isProcessingPhoto = false
    private(set) var photoFailed = false

    // Submission
    private(set) var isSubmitting = false
    private(set) var submitError: BackendError?
    private(set) var submitted: SubmittedReport?

    private var streetTask: Task<Void, Never>?

    // MARK: Derived state

    var hasInput: Bool { category != nil || !note.isEmpty || photo != nil }

    var textIssues: Set<TextIssue> {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? [] : TextPolicy.issues(in: trimmed)
    }

    var placeIssues: Set<ReportValidationIssue> {
        guard let coordinate else { return [] }
        return ReportRules.validate(coordinate: coordinate, occurredAt: occurredAt, note: nil)
    }

    var canContinue: Bool {
        switch step {
        case .what: category != nil
        case .whereWhen: coordinate != nil && placeIssues.isEmpty
        case .details: textIssues.isEmpty && !isProcessingPhoto && !isSubmitting
        }
    }

    /// Oldest selectable time: 7 days ago (server rule).
    var earliestDate: Date { Date().addingTimeInterval(-ReportRules.maxAge) }

    // MARK: Navigation

    /// Road and cleanliness advance on their own for speed. Serious categories stay on
    /// screen so the "help first" banner is read (spec §4.4).
    func choose(_ category: ReportCategory) -> Bool {
        self.category = category
        return !category.isSerious
    }

    func advance() {
        guard canContinue, let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    // MARK: Where

    func locate(with location: LocationService, locale: Locale) async {
        guard coordinate == nil else { return }
        isLocating = true
        defer { isLocating = false }
        if let here = await location.currentCoordinate() {
            camera = .region(MKCoordinateRegion(center: here.clCoordinate, latitudinalMeters: 350, longitudinalMeters: 350))
            setPin(here, locale: locale)
        } else {
            // No fix: start from the city centre; the user drags the map under the pin.
            locationUnavailable = true
            setPin(Brussels.center, locale: locale)
        }
    }

    /// The pin stays centred; moving the map moves the place ("épingle déplaçable").
    func setPin(_ center: GeoCoordinate, locale: Locale) {
        coordinate = center
        streetTask?.cancel()
        streetTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            let name = await StreetNamer.streetName(near: center, locale: locale)
            if !Task.isCancelled { streetName = name }
        }
    }

    // MARK: Photo

    func attach(_ image: UIImage) async {
        isProcessingPhoto = true
        photoFailed = false
        defer { isProcessingPhoto = false }
        do {
            let anonymised = try await PhotoAnonymizer.anonymise(image)
            photo = anonymised
            originalJPEG = image.jpegData(compressionQuality: 0.9)
        } catch {
            photo = nil
            originalJPEG = nil
            photoFailed = true
        }
    }

    func removePhoto() {
        photo = nil
        originalJPEG = nil
    }

    // MARK: Submit

    func submit(backend: any Backend, store: LocalStore) async {
        guard let category, let coordinate, canContinue else { return }
        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }

        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let submission = ReportSubmission(
            category: category, coordinate: coordinate, occurredAt: occurredAt,
            note: trimmed.isEmpty ? nil : trimmed, anonymisedPhotoJPEG: photo?.jpeg
        )
        do {
            let result = try await backend.submit(submission)
            let originalFile = originalJPEG.flatMap { OriginalPhotoStore.save($0, id: result.id) }
            store.save(
                MyReport(
                    id: result.id, category: category, coordinate: coordinate, occurredAt: occurredAt,
                    createdAt: Date(), status: result.status, routedTo: nil, note: submission.note,
                    hasPhoto: photo != nil, confirmations: 0
                ),
                originalPhotoFile: originalFile
            )
            submitted = result
        } catch let error as BackendError {
            submitError = error
        } catch {
            submitError = .server(String(describing: error))
        }
    }
}
