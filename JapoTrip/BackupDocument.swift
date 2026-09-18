import SwiftUI
import UniformTypeIdentifiers

/// Wraps the JSON produced by `DataStore.exportBackupData()` so it can be
/// handed to the standard `.fileExporter` share sheet — the only way the
/// "visited" progress (otherwise trapped in this one device's UserDefaults,
/// see BUG-011 in the audit) can be backed up or moved to another device.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = fileData
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
