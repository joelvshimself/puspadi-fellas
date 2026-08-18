import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published var isListening = false
    @Published var transcript = ""
    @Published var isAvailable = false

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var silenceTimer: Timer?

    init(languageIdentifier: String = "id-ID") {
        setupRecognizer(languageIdentifier: languageIdentifier)
    }

    deinit {
        silenceTimer?.invalidate()
        if let audioEngine = audioEngine {
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
    }

    func updateLanguage(languageIdentifier: String) {
        setupRecognizer(languageIdentifier: languageIdentifier)
    }

    private func setupRecognizer(languageIdentifier: String) {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: languageIdentifier))
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        isAvailable = speechRecognizer?.isAvailable ?? false
    }

    func toggleListening(onTranscript: @escaping (String) -> Void) {
        if isListening {
            stopListening()
        } else {
            startListening(onTranscript: onTranscript)
        }
    }

    func startListening(onTranscript: @escaping (String) -> Void) {
        stopListening()

        SFSpeechRecognizer.requestAuthorization { authStatus in
            Task { @MainActor in
                guard authStatus == .authorized else {
                    print("Speech recognition not authorized")
                    return
                }

                let audioSession = AVAudioSession.sharedInstance()
                do {
                    try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                } catch {
                    print("AVAudioSession configuration failed: \(error)")
                    return
                }

                self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
                guard let recognitionRequest = self.recognitionRequest else { return }

                let engine = AVAudioEngine()
                self.audioEngine = engine

                let inputNode = engine.inputNode
                recognitionRequest.shouldReportPartialResults = true

                self.recognitionTask = self.speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                    if let result = result {
                        let text = result.bestTranscription.formattedString
                        Task { @MainActor in
                            self.transcript = text
                            onTranscript(text)
                            self.resetSilenceTimer()
                        }
                    }
                    if error != nil || (result?.isFinal ?? false) {
                        Task { @MainActor in
                            self.stopListening()
                        }
                    }
                }

                let recordingFormat = inputNode.outputFormat(forBus: 0)
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                    recognitionRequest.append(buffer)
                }

                engine.prepare()
                do {
                    try engine.start()
                    self.isListening = true
                    self.resetSilenceTimer()
                } catch {
                    print("AVAudioEngine start failed: \(error)")
                    self.stopListening()
                }
            }
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        // Auto-stop after 2.5 seconds of silence if user has spoken
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isListening else { return }
                if !self.transcript.isEmpty {
                    self.stopListening()
                }
            }
        }
    }

    func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        if let audioEngine = audioEngine {
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        audioEngine = nil
        isListening = false

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
}
