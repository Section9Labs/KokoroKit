import Foundation
import XCTest
@testable import QwenANE

final class SourcePartTests: XCTestCase {
    func testRangesPartitionOriginalTextAndMatchExistingRendererParts() throws {
        let passages = [
            "  La casa estaba en silencio cuando Elena regresó.\n\nTras la ventana, la lluvia borraba el contorno de las colinas. Dejó la carta sin abrir junto a la lámpara y esperó. En el piso de arriba, una tabla crujió. Esta vez estaba segura de haberlo oído.  ",
            "“Wait,” said Alice.\r\n\tShe turned toward the door — but nobody was there. " + String(repeating: "She listened carefully; the house was silent. ", count: 8),
            String(repeating: "彼女は窓を開けた。雨は静かに降っていた。🌧️\n", count: 12),
            String(repeating: "उसने कहा, ‘कहानी अभी बाकी है।’\n", count: 12),
            String(repeating: "a", count: 200),
        ]
        for text in passages {
            let parts = try QwenReadRules.splitWithRanges(text)
            XCTAssertEqual(parts.map(\.text), QwenReadRules.split(text))
            var end = 0
            for part in parts {
                XCTAssertEqual(part.range.location, end)
                let source = (text as NSString).substring(with: part.range)
                XCTAssertEqual(source.filter { !$0.isWhitespace }, part.text.filter { !$0.isWhitespace })
                end = NSMaxRange(part.range)
            }
            XCTAssertEqual(end, text.utf16.count)
        }
    }
    func testRepeatedWordsKeepDistinctOffsets() throws {
        let text = String(repeating: "No, no, no. ", count: 60)
        let parts = try QwenReadRules.splitWithRanges(text)
        XCTAssertGreaterThan(parts.count, 1)
        XCTAssertEqual(parts.map { (text as NSString).substring(with: $0.range) }.joined(), text)
    }
    func testWhitespaceOnlyDoesNotMakeAudioWork() throws {
        XCTAssertTrue(try QwenReadRules.splitWithRanges(" \n\t ").isEmpty)
    }
}
