//
//  ContentView.swift
//  audio-live-translation
//
//  Created by Bibin Joseph on 2025-03-29.
//

import SwiftUI
import Speech
import Translation

struct ContentView: View {
    
    enum Language: String, CaseIterable, Identifiable {
        case english = "English"
        case korean = "Korean"
        case spanish = "Spanish"
        case french = "French"
        case japanese = "Japanese"
        
        var id: String { self.rawValue }
        
        var localeIdentifier: String {
            switch self {
            case .english: return "en-US"
            case .korean: return "ko"
            case .spanish: return "es"
            case .french: return "fr_FR"
            case .japanese: return "ja"
            }
        }
    }
    
    @State private var presentImporter: Bool = false
    @State private var path: URL?
    @State private var transcript = ""
    @State private var liveTranscript = ""
    @State private var translation = ""
    @State private var document: MessageDocument = MessageDocument(message: "")
    @State private var presentExporter: Bool = false
    @State private var showingAlert: Bool = false
    @State private var selectedSourceLanguage: Language = .french
    @State private var selectedTargetLanguage: Language = .english
    @State private var isTranscribing: Bool = false
    @State private var showFileError: Bool = false
    @State private var isTranslating: Bool = false
    
    @State private var translationConfiguration: TranslationSession.Configuration?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                Text("Audio Transcription and Translation POC")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                
                // Language Pickers
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("Source Language")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Source Language", selection: $selectedSourceLanguage) {
                            ForEach(Language.allCases) { language in
                                Text(language.rawValue).tag(language)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Target Language")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Target Language", selection: $selectedTargetLanguage) {
                            ForEach(Language.allCases) { language in
                                Text(language.rawValue).tag(language)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                .padding(.horizontal)
                
                // File Selection
                HStack {
                    Text(path?.lastPathComponent ?? "No file selected")
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    Button(action: { presentImporter = true }) {
                        Label("Select File", systemImage: "folder")
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Action Buttons
                HStack(spacing: 20) {
                    Button(action: transcribe) {
                        Label("Transcribe", systemImage: "waveform")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(path == nil || isTranscribing)
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: prepareTranslate) {
                        Label("Translate", systemImage: "character.book.closed")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(transcript.isEmpty || isTranslating)
                    .buttonStyle(.bordered)
                    
                    Button(action: saveTranscript) {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(transcript.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                
                // Transcript Editor
                VStack(alignment: .leading) {
                    Text("Transcript (\(selectedSourceLanguage.rawValue))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                    TextEditor(text: $liveTranscript)
                        .font(.body)
                        .frame(height: 150)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .shadow(radius: 2)
                
                // Translation Editor
                VStack(alignment: .leading) {
                    Text("Translation (\(selectedTargetLanguage.rawValue))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                    TextEditor(text: $translation)
                        .font(.body)
                        .frame(height: 150)
                        
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .shadow(radius: 2)
                .translationTask(translationConfiguration) { session in
                    await translate(using: session)
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $presentImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result: result)
            }
            .fileExporter(
                isPresented: $presentExporter,
                document: document,
                contentType: .plainText,
                defaultFilename: "transcript_\(selectedSourceLanguage.rawValue)_to_\(selectedTargetLanguage.rawValue)"
            ) { result in
                handleExportResult(result: result)
            }
            .alert("Success", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The transcript file has been successfully saved")
            }
            .alert("Error", isPresented: $showFileError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please select an audio file first")
            }
        }
    }
    
    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            path = url
            _ = url.startAccessingSecurityScopedResource()
        case .failure(let error):
            print("File selection error: \(error.localizedDescription)")
        }
    }
    
    private func handleExportResult(result: Result<URL, Error>) {
        if case .success = result {
            showingAlert = true
        }
    }
    
    private func saveTranscript() {
        if transcript.isEmpty { return }
        document = MessageDocument(message: "\(transcript)\n\n--- TRANSLATION ---\n\(translation)")
        presentExporter = true
    }
    
    func transcribe() {
        guard let path = path else {
            showFileError = true
            return
        }
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    isTranscribing = true
                    liveTranscript = "Transcribing..."
                    transcribeFile(url: path)
                } else {
                    print("Transcription Permission Denied")
                }
            }
        }
    }
    
    func prepareTranslate() {
        if translationConfiguration == nil {
            translationConfiguration = TranslationSession.Configuration.init(source: nil,
                                                                             target: Locale(identifier: selectedTargetLanguage.localeIdentifier).language)
        } else {
            self.translationConfiguration?.invalidate()
        }
    }
    
    func translate(using session: TranslationSession) async {
        isTranslating = true
        translation = "Translating from \(selectedSourceLanguage.rawValue) to \(selectedTargetLanguage.rawValue)..."
        
        do {
            let response = try await session.translate(liveTranscript)
            translation = response.targetText
            print("Tranlation: \n\(response.targetText)")
        } catch {
            print(error.localizedDescription)
        }
        isTranslating = false
        
    }
    
    func transcribeFile(url: URL) {
        guard let myRecognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedSourceLanguage.localeIdentifier)) else {
            print("The recognizer is not supported for the current locale")
            isTranscribing = false
            return
        }
        
        if !myRecognizer.isAvailable {
            print("The recognizer is not available")
            isTranscribing = false
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        print("About to create recognition task...")
        var lastRecognizedText = ""
        
        myRecognizer.recognitionTask(with: request) { (result, error) in
            DispatchQueue.main.async {
                guard let result = result else {
                    print("Recognition failed: \(error?.localizedDescription ?? "Unknown error")")
                    isTranscribing = false
                    return
                }
                
                let latestTranscription = result.bestTranscription.formattedString
                
                if latestTranscription.count > lastRecognizedText.count {
                    liveTranscript = latestTranscription
                    lastRecognizedText = latestTranscription
                }
                
                if result.isFinal {
                    print("Final Transcript: \(latestTranscription)")
                    transcript = liveTranscript
                    isTranscribing = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
