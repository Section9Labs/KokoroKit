// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import AVFoundation
import LibroxTTS
import SwiftUI

@main struct KokoroDemo: App {
    var body: some Scene { WindowGroup { DemoView() } }
}

struct DemoView: View {
    @State private var voiceID = "af_heart"
    @State private var text = Language.english.sampleText
    @State private var status = "Download the model once, then use it offline."
    @State private var busy = false
    @State private var player: AVAudioPlayer?
    private let directory = URL.applicationSupportDirectory.appending(path: "KokoroModels")

    var body: some View {
        NavigationStack {
            Form {
                Picker("Voice", selection: $voiceID) {
                    ForEach(Voice.all) { voice in
                        Text("\(voice.name) · \(voice.localeIdentifier)").tag(voice.id)
                    }
                }
                .onChange(of: voiceID) { _, id in text = Voice.named(id)!.language.sampleText }
                TextEditor(text: $text).frame(minHeight: 160)
                Button("Download model") { perform {
                    try await ModelAssets.download(to: directory)
                    status = "All 54 voices installed."
                } }
                Button("Speak") { perform {
                    let engine = KokoroEngine(modelDirectory: directory,
                        pronunciationPolicy: .independent,
                        rendererPolicy: .fixedSize(directory: directory.appending(path: "decoder")))
                    let audio = try await engine.synthesize(text, voiceID: voiceID)
                    await engine.unload()
                    let format = AVAudioFormat(standardFormatWithSampleRate: Double(audio.sampleRate), channels: 1)!
                    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audio.samples.count))!
                    buffer.frameLength = buffer.frameCapacity
                    audio.samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: $0.count) }
                    let url = URL.temporaryDirectory.appending(path: "kokoro-demo.wav")
                    do {
                        let file = try AVAudioFile(forWriting: url, settings: format.settings)
                        try file.write(from: buffer)
                    }
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.playback, mode: .spokenAudio)
                    try session.setActive(true)
                    player = try AVAudioPlayer(contentsOf: url)
                    player?.play()
                    status = "Playing \(audio.duration.formatted(.number.precision(.fractionLength(1)))) seconds."
                } }
                Button("Stop") {
                    player?.stop()
                    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                    status = "Stopped."
                }
                Text(status).font(.footnote)
            }
            .disabled(busy)
            .navigationTitle("LibroxTTS")
        }
    }
    private func perform(_ operation: @escaping @MainActor () async throws -> Void) {
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do { try await operation() } catch { status = error.localizedDescription }
        }
    }
}
