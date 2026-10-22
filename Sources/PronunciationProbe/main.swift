// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation
import KokoroPronunciation

let arguments = CommandLine.arguments
guard arguments.count >= 3, let language = PronunciationLanguage(rawValue: arguments[1]) else {
    FileHandle.standardError.write(Data("Usage: pronunciation-probe <language> <text> [--british] [--adverb-stress] [--plan] [--target=180]\n".utf8))
    exit(2)
}
let flags = ["--british", "--adverb-stress", "--plan", "--single-language"]
let text = arguments.dropFirst(2).filter { !flags.contains($0) && !$0.hasPrefix("--target=") }.joined(separator: " ")
struct PreparedUnit: Encodable {
    let text: String
    let boundary: NarrationBoundary
    let pronunciation: PronunciationResult
}
do {
    let options = PronunciationOptions(britishEnglish: arguments.contains("--british"),
        spanishAdverbDoubleStress: arguments.contains("--adverb-stress"),
        mixedLanguage: arguments.contains("--single-language") ? .disabled : .automatic)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let engine = PronunciationEngine()
    let data: Data
    if arguments.contains("--plan") {
        let target = arguments.first(where: { $0.hasPrefix("--target=") }).flatMap { Int($0.dropFirst(9)) } ?? 180
        let units = try NarrationPlanner().plan(text, language: language, options: options, targetPhonemes: target)
        data = try encoder.encode(units.map {
            PreparedUnit(text: $0.text, boundary: $0.boundaryAfter,
                         pronunciation: try engine.phonemize($0.text, language: language, options: options))
        })
    } else {
        data = try encoder.encode(engine.phonemize(text, language: language, options: options))
    }
    FileHandle.standardOutput.write(data + Data([10]))
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
