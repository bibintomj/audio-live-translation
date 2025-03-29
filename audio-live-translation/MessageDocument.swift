//
//  MessageDocument.swift
//  audio-live-translation
//
//  Created by Bibin Joseph on 2025-03-29.
//

import SwiftUI
import UniformTypeIdentifiers

struct MessageDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var message: String
    init(message: String) {
        self.message = message
    }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        message = string
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: message.data(using: .utf8)!)
    }
}
