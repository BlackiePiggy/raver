import Foundation

extension Foundation.Bundle {
    static let module: Bundle = {
        let mainPath = Bundle.main.bundleURL.appendingPathComponent("SwiftSunburstPrototype_SunburstPreview.bundle").path
        let buildPath = "/Users/blackie/Documents/New project/pulse.roots/SwiftSunburstPrototype/.build/arm64-apple-macosx/debug/SwiftSunburstPrototype_SunburstPreview.bundle"

        let preferredBundle = Bundle(path: mainPath)

        guard let bundle = preferredBundle ?? Bundle(path: buildPath) else {
            // Users can write a function called fatalError themselves, we should be resilient against that.
            Swift.fatalError("could not load resource bundle: from \(mainPath) or \(buildPath)")
        }

        return bundle
    }()
}