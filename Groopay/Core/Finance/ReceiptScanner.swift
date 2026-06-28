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

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self else { return }
            if let error {
                Task { @MainActor in
                    self.error = error.localizedDescription
                }
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            var textLines: [String] = []
            for observation in observations {
                if let candidate = observation.topCandidates(1).first {
                    textLines.append(candidate.string)
                }
            }

            let joinedText = textLines.joined(separator: "\n")
            Task { @MainActor in
                self.recognizedText = joinedText
            }
        }

        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["tr-TR", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            self.error = error.localizedDescription
        }
    }
}
