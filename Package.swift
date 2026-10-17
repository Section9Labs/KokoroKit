// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KokoroKit",
    platforms: [.macOS(.v13), .iOS(.v17), .macCatalyst(.v17)],
    products: [
        .library(name: "KokoroKit", targets: ["KokoroKit"]),
        .library(name: "KokoroCatalog", targets: ["KokoroCatalog"]),
        .library(name: "KokoroPronunciation", targets: ["KokoroPronunciation"]),
        .executable(name: "kokoro-probe", targets: ["KokoroProbe"]),
        .executable(name: "pronunciation-probe", targets: ["PronunciationProbe"]),
    ],
    targets: [
        .systemLibrary(name: "CZlib"),
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
    ]
)
