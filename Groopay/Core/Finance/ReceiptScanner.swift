import SwiftUI
import Vision

@Observable
@MainActor
final class ReceiptScanner {
    var isProcessing = false
    var recognizedText: String? = nil
    var error: String? = nil

    func scan(image: UIImage) async {
        isProcessing = true
        error = nil
        recognizedText = nil

        defer {
            isProcessing = false
        }

        guard let cgImage = image.cgImage else {
            error = String(localized: "Görsel formatı desteklenmiyor.", comment: "Error when cgImage conversion fails")
            return
        }

        do {
            recognizedText = try await performRecognition(cgImage: cgImage)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Bridges the callback-based Vision API to async/await with `withCheckedContinuation`.
    /// Called from the Main Actor context, so the result is available before the caller resumes.
    private nonisolated func performRecognition(cgImage: CGImage) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                let textLines: [String] = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let joinedText = textLines.isEmpty ? nil : textLines.joined(separator: "\n")
                continuation.resume(returning: joinedText)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["tr-TR", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                // Vision threw synchronously (invalid image, etc.) — completion handler
                // will not be called, so resume the continuation here.
                continuation.resume(throwing: error)
            }
        }
    }
}
