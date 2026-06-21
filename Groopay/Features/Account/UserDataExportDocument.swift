import SwiftUI
import UniformTypeIdentifiers

/// `fileExporter` için hafif JSON belge sarmalayıcısı. UIKit rootViewController
/// üzerinden manuel sunum yerine SwiftUI-native dışa aktarım sağlar.
struct UserDataExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
