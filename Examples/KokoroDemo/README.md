# iOS / Catalyst demo

Requires Xcode and XcodeGen (`brew install xcodegen`). From this directory run `xcodegen generate`, then open `KokoroDemo.xcodeproj`. Select your development team to run on an iPhone. The example enables background audio and uses the independent frontend plus fixed-size decoder.

Download once, select a voice, enter a short passage, and tap Speak. The example synthesizes the whole passage before playback; it is not a continuous audiobook queue. Model assets require iOS/Catalyst 18+. Do not infer device memory acceptance from the generic iOS CI build.
