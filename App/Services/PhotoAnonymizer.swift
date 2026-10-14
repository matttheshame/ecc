import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

/// The photo that may leave the device: faces and licence plates destroyed, metadata
/// (EXIF, GPS) stripped by re-encoding, long side ≤ 2048 px.
struct AnonymisedPhoto: Sendable {
    let jpeg: Data
    let preview: UIImage
    let facesBlurred: Int
    let platesBlurred: Int
}

enum PhotoAnonymizerError: Error {
    case unreadableImage
    case encodingFailed
}

/// On-device anonymisation with Vision (spec §4.3: "floutage automatique des visages
/// et des plaques d'immatriculation avant tout envoi"). Nothing is uploaded until this
/// has run and the user has seen the result.
///
/// Faces: `VNDetectFaceRectanglesRequest`, boxes enlarged to cover hair and chin.
/// Plates: Vision has no plate detector, so two signals are combined: recognised text
/// that looks like a plate, and plate-shaped rectangles that contain text.
/// Regions are pixellated *and* blurred so they cannot be reconstructed.
enum PhotoAnonymizer {
    static func anonymise(_ image: UIImage) async throws -> AnonymisedPhoto {
        try await Task.detached(priority: .userInitiated) {
            try process(image)
        }.value
    }

    nonisolated static func process(_ image: UIImage) throws -> AnonymisedPhoto {
        let upright = normalise(image, maxDimension: 2048)
        guard let cgImage = upright.cgImage else { throw PhotoAnonymizerError.unreadableImage }

        let faces = VNDetectFaceRectanglesRequest()
        let text = VNRecognizeTextRequest()
        text.recognitionLevel = .accurate
        text.usesLanguageCorrection = false
        let rectangles = VNDetectRectanglesRequest()
        rectangles.minimumAspectRatio = 0.12   // shorter / longer side; EU plates ≈ 0.21
        rectangles.maximumAspectRatio = 0.40
        rectangles.minimumSize = 0.02
        rectangles.maximumObservations = 12
        rectangles.minimumConfidence = 0.5

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try handler.perform([faces, text, rectangles])

        // Normalised rects, origin bottom-left (Vision and Core Image agree).
        var regions: [CGRect] = []

        let faceBoxes = (faces.results ?? []).map { face in
            face.boundingBox.insetBy(dx: -face.boundingBox.width * 0.3, dy: -face.boundingBox.height * 0.4)
        }
        regions += faceBoxes

        let textObservations = text.results ?? []
        var plateBoxes: [CGRect] = []
        for observation in textObservations {
            guard let candidate = observation.topCandidates(1).first?.string else { continue }
            if looksLikePlate(candidate) {
                plateBoxes.append(observation.boundingBox.insetBy(dx: -observation.boundingBox.width * 0.25, dy: -observation.boundingBox.height * 0.6))
            }
        }
        for rectangle in rectangles.results ?? [] {
            let box = rectangle.boundingBox
            let containsText = textObservations.contains { box.contains(CGPoint(x: $0.boundingBox.midX, y: $0.boundingBox.midY)) }
            if containsText, !plateBoxes.contains(where: { $0.intersects(box) }) {
                plateBoxes.append(box.insetBy(dx: -box.width * 0.1, dy: -box.height * 0.2))
            }
        }
        regions += plateBoxes

        let output = regions.isEmpty ? cgImage : try blur(cgImage, regions: regions)
        let result = UIImage(cgImage: output)
        // Re-encoding from pixels drops every metadata block, GPS included.
        guard let jpeg = result.jpegData(compressionQuality: 0.8) else { throw PhotoAnonymizerError.encodingFailed }
        return AnonymisedPhoto(jpeg: jpeg, preview: result, facesBlurred: faceBoxes.count, platesBlurred: plateBoxes.count)
    }

    /// Belgian (1-ABC-123) and generic European plates: 5–9 characters mixing letters and digits.
    nonisolated static func looksLikePlate(_ raw: String) -> Bool {
        let compact = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        guard (5...9).contains(compact.count) else { return false }
        let hasLetter = compact.contains(where: \.isLetter)
        let hasDigit = compact.contains(where: \.isNumber)
        return hasLetter && hasDigit
    }

    nonisolated private static func blur(_ cgImage: CGImage, regions: [CGRect]) throws -> CGImage {
        let source = CIImage(cgImage: cgImage)
        let extent = source.extent
        let blockSize = max(extent.width, extent.height) / 48

        let pixellate = CIFilter.pixellate()
        pixellate.inputImage = source.clampedToExtent()
        pixellate.scale = Float(max(blockSize, 12))
        let destroyed = (pixellate.outputImage ?? source)
            .applyingGaussianBlur(sigma: Double(blockSize) * 0.6)
            .cropped(to: extent)

        var mask = CIImage(color: .black).cropped(to: extent)
        for region in regions {
            let rect = VNImageRectForNormalizedRect(region.intersection(CGRect(x: 0, y: 0, width: 1, height: 1)), Int(extent.width), Int(extent.height))
            mask = CIImage(color: .white).cropped(to: rect).composited(over: mask)
        }

        let blend = CIFilter.blendWithMask()
        blend.inputImage = destroyed
        blend.backgroundImage = source
        blend.maskImage = mask
        guard let output = blend.outputImage,
              let rendered = CIContext().createCGImage(output, from: extent) else {
            throw PhotoAnonymizerError.encodingFailed
        }
        return rendered
    }

    /// Redraws upright at 1× scale, downscaled to `maxDimension`.
    nonisolated private static func normalise(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let factor = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: (size.width * factor).rounded(), height: (size.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
