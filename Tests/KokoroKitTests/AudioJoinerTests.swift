// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Testing
@testable import LibroxTTS

@Test func artificialJoinsRemoveOnlyQuietEdges() {
    let speech = Array(repeating: Float(0.1), count: 2_400)
    let silence = Array(repeating: Float(0), count: 12_000)
    var first = speech + silence
    AudioJoiner.append(silence + speech, to: &first, after: "hɛlˈoʊ ")
    #expect(first.count == speech.count * 2 + 1_440) // 30 ms each side
    #expect(Array(first.prefix(speech.count)) == speech)
    #expect(Array(first.suffix(speech.count)) == speech)
}

@Test(arguments: ["hɛlˈoʊ.", "hɛlˈoʊ, ", "hɛlˈoʊ?\" ", "hɛlˈoʊ！", "hɛlˈoʊ—"])
func writtenPausesStayIntact(_ phonemes: String) {
    let samples = Array(repeating: Float(0.1), count: 240) + Array(repeating: Float(0), count: 12_000)
    let next = Array(samples.reversed())
    var joined = samples
    AudioJoiner.append(next, to: &joined, after: phonemes)
    #expect(joined == samples + next)
}

@Test func quietInteriorAndSoftSpeechAreNotCut() {
    let speech = Array(repeating: Float(0.002), count: 2_400)
    let interior = Array(repeating: Float(0), count: 12_000)
    let samples = speech + interior + speech
    var joined = samples
    AudioJoiner.append(samples, to: &joined, after: "hɛlˈoʊ")
    #expect(joined == samples + samples)
}

@Test func clauseBoundaryWinsOverLaterWhitespace() {
    let text = "a long phrase, and more words at the end"
    let chunks = KokoroEngine.chunks(text, limit: 25)
    #expect(chunks.first == "a long phrase,")
    #expect(chunks.joined() == text)
}
