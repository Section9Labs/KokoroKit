// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KokoroKit",
    platforms: [.macOS(.v13), .iOS(.v17), .macCatalyst(.v17)],
    products: [
        .library(name: "KokoroKit", targets: ["KokoroKit"]),
        .library(name: "KokoroCatalog", targets: ["KokoroCatalog"]),
        .library(name: "KokoroPronunciation", targets: ["KokoroPronunciation"]),
        .library(name: "KokoroAudio", targets: ["KokoroAudio"]),
        .library(name: "KokoroNarration", targets: ["KokoroNarration"]),
        .executable(name: "kokoro-probe", targets: ["KokoroProbe"]),
        .executable(name: "pronunciation-probe", targets: ["PronunciationProbe"]),
    ],
    targets: [
        .systemLibrary(name: "CZlib"),
        .target(name: "KokoroAudio"),
        .target(name: "KokoroNarration", dependencies: ["KokoroCatalog", "KokoroPronunciation"]),
        .testTarget(name: "KokoroNarrationTests", dependencies: ["KokoroNarration"]),
        .target(name: "KokoroCatalog", resources: [.process("Assets.json")]),
        .target(name: "PronunciationEnglish", resources: [.process("Resources")]),
        .target(name: "KokoroPronunciation", dependencies: ["PronunciationEnglish"],
                resources: [.process("Resources")]),
        .target(name: "KokoroKit", dependencies: ["KokoroCatalog", "CZlib", "KokoroPronunciation"],
                resources: [.process("Resources")]),
        .executableTarget(name: "KokoroProbe", dependencies: ["KokoroKit"]),
        .executableTarget(name: "PronunciationProbe", dependencies: ["KokoroPronunciation"]),
        .testTarget(name: "KokoroKitTests", dependencies: ["KokoroKit", "KokoroCatalog", "KokoroPronunciation"]),
        .testTarget(name: "KokoroPronunciationTests", dependencies: ["KokoroPronunciation"]),
        .testTarget(name: "KokoroAudioTests", dependencies: ["KokoroAudio"]),
    ]
)
