// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors
import Foundation
import KokoroPronunciation

let arguments = CommandLine.arguments
guard arguments.count >= 3, let language = PronunciationLanguage(rawValue: arguments[1]) else {
    FileHandle.standardError.write(Data("Usage: pronunciation-probe <en|es|fr|hi|it|ja|zh|pt> <text> [--british]\n".utf8))
    exit(2)
}
let text = arguments.dropFirst(2).filter { $0 != "--british" }.joined(separator: " ")
do {
    let result = try PronunciationEngine().phonemize(text, language: language,
        options: .init(britishEnglish: arguments.contains("--british")))
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    FileHandle.standardOutput.write(try encoder.encode(result) + Data([10]))
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
