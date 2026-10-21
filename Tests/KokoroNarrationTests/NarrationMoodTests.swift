// SPDX-License-Identifier: Apache-2.0 OR MIT
import Testing
@testable import KokoroNarration

@Test(arguments: [
    ("she said angrily.", "en", NarrationMood.angry),
    (", Nora said with joy.", "en", .joyful),
    ("dijo Nora con rabia.", "es", .angry),
    (", respondió con alivio.", "es", .relieved),
    ("Nora respondió con alegría.", "es", .joyful),
    ("he asked fearfully.", "en", .fearful),
    ("she replied sadly.", "en", .sad),
    ("she snapped.", "en", .angry)
]) func explicitMoodCue(cue: String, language: String, mood: NarrationMood) {
    #expect(NarrationMoodDetector.analyze(followingAttribution: cue, languageCode: language).mood == mood)
}

@Test(arguments: ["she said, not angrily.", "she said without anger.", "she said. Nora was angry.",
    "she said happily but he was angry.", "she shouted.", "she said that he was angry.",
    "\n\nshe said angrily.", "she pretended to speak angrily.", "he snapped the branch.",
    "dijo sin rabia.", "dijo. Estaba furiosa.", "gritó."])
func moodAbstainsFromAmbiguousOrUnrelatedCues(_ cue: String) {
    for language in ["en", "es"] {
        #expect(NarrationMoodDetector.analyze(followingAttribution: cue, languageCode: language).mood == .neutral)
    }
}

@Test func moodIsBoundedAndLanguageSpecific() {
    #expect(NarrationMoodDetector.analyze(followingAttribution: "she said angrily.", languageCode: "fr").mood == .neutral)
    #expect(NarrationMoodDetector.analyze(followingAttribution: String(repeating: "x", count: 193), languageCode: "en").mood == .neutral)
}
